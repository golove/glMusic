//
//  AudioSpectrumManager.swift
//  glMusic
//
//  Created by go love on 11/13/26.
//

import Foundation
import AVFoundation
import MediaToolbox
import Accelerate
import os

/// 实时音频三频段（低音、中音、高音）频谱分析引擎
/// 基于 MTAudioProcessingTap 挂载到 AVPlayerItem 音频管线，零延迟截取 PCM 数据，
/// 并通过 Apple Accelerate (vDSP FFT) 毫秒级提取 Bass / Mid / Treble 能量与物理弹簧打击回弹。
final class AudioSpectrumManager: @unchecked Sendable {
    static let shared = AudioSpectrumManager()

    /// 经过物理平滑后的三频归一化高度 (0.0 ~ 1.0)
    /// - bass: 低音（底鼓、808贝斯、重低音，20Hz ~ 250Hz）
    /// - mid: 中音（人声歌唱、钢琴、主旋律吉他，250Hz ~ 3500Hz）
    /// - treble: 高音（踩镲、镲片、空气感高频，3500Hz ~ 16000Hz）
    private(set) var currentLevels: (bass: CGFloat, mid: CGFloat, treble: CGFloat) = (0, 0, 0)

    /// 当前是否有真实音频信号输入（若音轨未就绪或缓冲静音，则为 false，平滑回退至基准动效）
    private(set) var isAudioActive: Bool = false

    // MARK: - Ring Buffer (线程安全无锁环形采样池)

    private let sampleCapacity = 2048
    private var sampleBuffer = [Float](repeating: 0, count: 2048)
    private var sampleBufferLock = os_unfair_lock()
    private var hasNewSamples: Bool = false

    // MARK: - FFT & Accelerate Setup

    private let log2n = 10 // 1024 points (~21.3ms @ 48kHz)
    private let n = 1024
    private let fftSetup: FFTSetup
    private var hannWindow: [Float]

    // MARK: - Reusable FFT Buffers (杜绝 30 FPS 渲染循环中的频繁堆内存分配)

    private var localSamplesBuffer: [Float]
    private var windowedBuffer: [Float]
    private var realpBuffer: [Float]
    private var imagpBuffer: [Float]
    private var magsBuffer: [Float]

    // MARK: - AGC & Beat Detection (自动增益与动态瞬态重拍检测)

    private var peakBass: Float = 0.20
    private var peakMid: Float = 0.20
    private var peakTreble: Float = 0.20

    private var avgBass: Float = 0.0
    private var avgMid: Float = 0.0
    private var avgTreble: Float = 0.0
    private var isBandTrackerInitialized: Bool = false

    // MARK: - Physics State (Attack / Decay 弹簧回弹物理模型)

    private var smoothedBass: Float = 0
    private var smoothedMid: Float = 0
    private var smoothedTreble: Float = 0

    // MARK: - Tap & Format State

    private struct TapFormat {
        var sampleRate: Double = 44100.0
        var channels: UInt32 = 2
        var isFloat: Bool = true
        var isNonInterleaved: Bool = true
        var bitsPerChannel: UInt32 = 32
    }

    private var tapFormats: [UUID: TapFormat] = [:]
    private var currentTapFormat = TapFormat()

    /// Each player item owns its own tap. During crossfade the incoming tap becomes the
    /// active source so callbacks from the outgoing player cannot overwrite its samples.
    private final class TapContext {
        weak var manager: AudioSpectrumManager?
        let id: UUID

        init(manager: AudioSpectrumManager, id: UUID) {
            self.manager = manager
            self.id = id
        }
    }

    private var activeTapID: UUID?

    private init() {
        self.fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))!
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        self.hannWindow = window

        self.localSamplesBuffer = [Float](repeating: 0, count: n)
        self.windowedBuffer = [Float](repeating: 0, count: n)
        self.realpBuffer = [Float](repeating: 0, count: n / 2)
        self.imagpBuffer = [Float](repeating: 0, count: n / 2)
        self.magsBuffer = [Float](repeating: 0, count: n / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Tap Format Lifecycle

    private func handlePrepare(format: AudioStreamBasicDescription, maxFrames: CMItemCount, tapID: UUID) {
        let isFloat = (format.mFormatFlags & AudioFormatFlags(kAudioFormatFlagIsFloat)) != 0
        let isNonInterleaved = (format.mFormatFlags & AudioFormatFlags(kAudioFormatFlagIsNonInterleaved)) != 0
        let sampleRate = format.mSampleRate > 0 ? format.mSampleRate : 44100.0
        let parsed = TapFormat(
            sampleRate: sampleRate,
            channels: max(1, format.mChannelsPerFrame),
            isFloat: isFloat,
            isNonInterleaved: isNonInterleaved,
            bitsPerChannel: format.mBitsPerChannel
        )

        os_unfair_lock_lock(&sampleBufferLock)
        tapFormats[tapID] = parsed
        if activeTapID == tapID {
            currentTapFormat = parsed
        }
        os_unfair_lock_unlock(&sampleBufferLock)
    }

    private func handleUnprepare(tapID: UUID) {
        os_unfair_lock_lock(&sampleBufferLock)
        tapFormats.removeValue(forKey: tapID)
        os_unfair_lock_unlock(&sampleBufferLock)
    }

    // MARK: - MTAudioProcessingTap Setup

    private func makeAudioTap(id: UUID) -> MTAudioProcessingTap? {
        let context = TapContext(manager: self, id: id)
        let clientPtr = UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque())
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientPtr,
            init: { tap, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let storage = MTAudioProcessingTapGetStorage(tap)
                Unmanaged<TapContext>.fromOpaque(storage).release()
            },
            prepare: { tap, maxFrames, processingFormat in
                let storage = MTAudioProcessingTapGetStorage(tap)
                let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
                context.manager?.handlePrepare(format: processingFormat.pointee, maxFrames: maxFrames, tapID: context.id)
            },
            unprepare: { tap in
                let storage = MTAudioProcessingTapGetStorage(tap)
                let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
                context.manager?.handleUnprepare(tapID: context.id)
            },
            process: { tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
                guard status == noErr else { return }

                let storage = MTAudioProcessingTapGetStorage(tap)
                let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
                context.manager?.ingestPCM(bufferList: bufferListInOut.pointee, numberFrames: numberFrames, tapID: context.id)
            }
        )

        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
        guard status == noErr else {
            Unmanaged<TapContext>.fromOpaque(clientPtr).release()
            print("⚠️ [AudioSpectrum] 创建 MTAudioProcessingTap 失败: \(status)")
            return nil
        }
        return tap
    }

    private func updateActiveTapID(_ tapID: UUID) {
        os_unfair_lock_lock(&sampleBufferLock)
        activeTapID = tapID
        if let fmt = tapFormats[tapID] {
            currentTapFormat = fmt
        }
        os_unfair_lock_unlock(&sampleBufferLock)
    }

    /// 将音频探针挂载到指定的 AVPlayerItem 上
    func attachTap(to item: AVPlayerItem) async {
        do {
            let tracks = try await item.asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { return }

            let tapID = UUID()
            guard let tap = makeAudioTap(id: tapID) else { return }
            updateActiveTapID(tapID)

            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
            #if DEBUG
            print("🎧 [AudioSpectrum] 成功挂载音频实时频谱监听探针")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [AudioSpectrum] 挂载音频探针异常: \(error)")
            #endif
        }
    }

    // MARK: - Real-time Audio Ingestion (音频实时线程)

    private func ingestPCM(bufferList: AudioBufferList, numberFrames: CMItemCount, tapID: UUID) {
        guard numberFrames > 0 else { return }

        os_unfair_lock_lock(&sampleBufferLock)
        guard activeTapID == tapID else {
            os_unfair_lock_unlock(&sampleBufferLock)
            return
        }

        let fmt = currentTapFormat
        let count = min(Int(numberFrames), sampleCapacity)

        withUnsafePointer(to: bufferList.mBuffers) { bufPtr in
            let buffers = UnsafeBufferPointer(start: bufPtr, count: max(1, Int(bufferList.mNumberBuffers)))
            guard let firstData = buffers[0].mData else { return }

            sampleBuffer.withUnsafeMutableBufferPointer { dest in
                let dPtr = dest.baseAddress!

                if fmt.isFloat {
                    let p0 = firstData.assumingMemoryBound(to: Float.self)
                    if fmt.isNonInterleaved && buffers.count > 1, let secondData = buffers[1].mData {
                        let p1 = secondData.assumingMemoryBound(to: Float.self)
                        for i in 0..<count {
                            dPtr[i] = (p0[i] + p1[i]) * 0.5
                        }
                    } else if !fmt.isNonInterleaved && fmt.channels >= 2 {
                        for i in 0..<count {
                            dPtr[i] = (p0[i * 2] + p0[i * 2 + 1]) * 0.5
                        }
                    } else {
                        dPtr.update(from: p0, count: count)
                    }
                } else if fmt.bitsPerChannel == 16 {
                    let p0 = firstData.assumingMemoryBound(to: Int16.self)
                    if fmt.isNonInterleaved && buffers.count > 1, let secondData = buffers[1].mData {
                        let p1 = secondData.assumingMemoryBound(to: Int16.self)
                        for i in 0..<count {
                            dPtr[i] = (Float(p0[i]) + Float(p1[i])) * (0.5 / 32768.0)
                        }
                    } else if !fmt.isNonInterleaved && fmt.channels >= 2 {
                        for i in 0..<count {
                            dPtr[i] = (Float(p0[i * 2]) + Float(p0[i * 2 + 1])) * (0.5 / 32768.0)
                        }
                    } else {
                        for i in 0..<count {
                            dPtr[i] = Float(p0[i]) / 32768.0
                        }
                    }
                } else {
                    let p0 = firstData.assumingMemoryBound(to: Float.self)
                    dPtr.update(from: p0, count: count)
                }
            }
        }
        hasNewSamples = true
        os_unfair_lock_unlock(&sampleBufferLock)
    }

    // MARK: - Analysis (按需驱动 30 FPS 频域解析与物理阻尼)

    /// 由动画渲染循环按需调用，执行单帧 FFT 频域能量提取与物理阻尼计算
    func updateLevelsForNextFrame() {
        performSpectrumAnalysis()
    }

    private func performSpectrumAnalysis() {
        var shouldAnalyze = false
        var sampleRate: Double = 44100.0

        os_unfair_lock_lock(&sampleBufferLock)
        if hasNewSamples {
            sampleBuffer.withUnsafeBufferPointer { src in
                localSamplesBuffer.withUnsafeMutableBufferPointer { dest in
                    dest.baseAddress!.update(from: src.baseAddress!, count: n)
                }
            }
            sampleRate = currentTapFormat.sampleRate
            hasNewSamples = false
            shouldAnalyze = true
        }
        os_unfair_lock_unlock(&sampleBufferLock)

        guard shouldAnalyze else {
            // 无新数据输入时，阻尼衰减回落
            decayLevels()
            return
        }

        // 1. 加窗（Hann Window 减少频谱泄漏，复用预分配缓冲区）
        vDSP_vmul(localSamplesBuffer, 1, hannWindow, 1, &windowedBuffer, 1, vDSP_Length(n))

        // 2. 实数转复数格式 (Real-to-Complex)
        realpBuffer.withUnsafeMutableBufferPointer { rPtr in
            imagpBuffer.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)

                windowedBuffer.withUnsafeBytes { raw in
                    let ptr = raw.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(ptr.baseAddress!, 2, &split, 1, vDSP_Length(n / 2))
                }

                // 3. 执行单精度快速傅里叶变换 (vDSP Forward FFT)
                vDSP_fft_zrip(fftSetup, &split, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))

                // 4. 计算各频点能量幅值 (Magnitudes，复用 magsBuffer)
                vDSP_zvmags(&split, 1, &magsBuffer, 1, vDSP_Length(n / 2))

                // 5. 根据采样率自适应计算三频 Bin 索引范围（消除 48kHz/96kHz 频段漂移）：
                //    - 低音 (Bass): 20Hz ~ 260Hz
                //    - 中音 (Mid): 260Hz ~ 3500Hz
                //    - 高音 (Treble): 3500Hz ~ 15000Hz
                let binWidth = max(1.0, sampleRate / Double(n))
                let bStart = max(1, min(Int(20.0 / binWidth), n / 2 - 2))
                let bEnd = max(bStart + 1, min(Int(260.0 / binWidth), n / 2 - 2))
                let bCount = bEnd - bStart + 1

                let mStart = min(bEnd + 1, n / 2 - 2)
                let mEnd = max(mStart + 1, min(Int(3500.0 / binWidth), n / 2 - 2))
                let mCount = mEnd - mStart + 1

                let tStart = min(mEnd + 1, n / 2 - 2)
                let tEnd = max(tStart + 1, min(Int(15000.0 / binWidth), n / 2 - 1))
                let tCount = tEnd - tStart + 1

                magsBuffer.withUnsafeBufferPointer { mPtr in
                    let basePtr = mPtr.baseAddress!

                    var bSum: Float = 0
                    vDSP_sve(basePtr + bStart, 1, &bSum, vDSP_Length(bCount))

                    var mSum: Float = 0
                    vDSP_sve(basePtr + mStart, 1, &mSum, vDSP_Length(mCount))

                    var tSum: Float = 0
                    vDSP_sve(basePtr + tStart, 1, &tSum, vDSP_Length(tCount))

                    let rawBass = sqrt(max(0, bSum / Float(bCount)))
                    let rawMid = sqrt(max(0, mSum / Float(mCount)))
                    let rawTreble = sqrt(max(0, tSum / Float(tCount)))

                    self.updateLevels(rawBass: rawBass, rawMid: rawMid, rawTreble: rawTreble)
                }
            }
        }
    }

    /// 自适应增益控制与门限节拍强化动力学处理
    private func updateLevels(rawBass: Float, rawMid: Float, rawTreble: Float) {
        let totalRaw = rawBass + rawMid + rawTreble
        if totalRaw < 0.005 {
            decayLevels()
            return
        }

        self.isAudioActive = true

        if !isBandTrackerInitialized {
            avgBass = rawBass
            avgMid = rawMid
            avgTreble = rawTreble
            peakBass = max(rawBass * 1.5, 0.20)
            peakMid = max(rawMid * 1.5, 0.20)
            peakTreble = max(rawTreble * 1.5, 0.20)
            isBandTrackerInitialized = true
        }

        // 1. 动态自适应峰值追踪器 (AGC): 维持合理的动态上限，避免过度压低峰值导致底噪抬升
        peakBass = max(peakBass * 0.993, rawBass, 0.20)
        peakMid = max(peakMid * 0.993, rawMid, 0.20)
        peakTreble = max(peakTreble * 0.993, rawTreble, 0.20)

        // 2. 短期背景伴奏均值追踪 (平滑系数 0.12，用于区分持续垫乐与突发重音)
        avgBass = avgBass * 0.88 + rawBass * 0.12
        avgMid = avgMid * 0.88 + rawMid * 0.12
        avgTreble = avgTreble * 0.88 + rawTreble * 0.12

        // 3. 动态瞬态打击乐与重音抽取：
        // 门限必须同时满足两重过滤：
        //   a) 必须高出当前背景伴奏能量达 30%~35% (排除平稳人声和垫乐)；
        //   b) 必须达到绝对声学门限 (0.16 / 0.15 / 0.16)。
        // 平稳伴奏期间输出恒等于 0.0，音符安安静静平卧在底部舞台，杜绝持续微颤！
        let targetBass = Self.calculateBeatImpulse(raw: rawBass, avg: avgBass, peak: peakBass, multiplier: 1.35, minThreshold: 0.16, power: 1.8)
        let targetMid = Self.calculateBeatImpulse(raw: rawMid, avg: avgMid, peak: peakMid, multiplier: 1.30, minThreshold: 0.15, power: 1.8)
        let targetTreble = Self.calculateBeatImpulse(raw: rawTreble, avg: avgTreble, peak: peakTreble, multiplier: 1.35, minThreshold: 0.16, power: 1.9)

        // 4. Attack & Decay 物理运动模拟：
        // 鼓点爆发时迅速冲上高点 (Attack 0.90)；
        // 衰落时以较重重力迅速落回地面 (0.68 - 0.04)，并在 < 0.05 时硬截断归零贴地，杜绝尾部微幅颤动。
        smoothedBass = targetBass > smoothedBass ? (smoothedBass + (targetBass - smoothedBass) * 0.90) : max(0, smoothedBass * 0.68 - 0.04)
        smoothedMid = targetMid > smoothedMid ? (smoothedMid + (targetMid - smoothedMid) * 0.85) : max(0, smoothedMid * 0.70 - 0.04)
        smoothedTreble = targetTreble > smoothedTreble ? (smoothedTreble + (targetTreble - smoothedTreble) * 0.90) : max(0, smoothedTreble * 0.68 - 0.04)

        if smoothedBass < 0.05 { smoothedBass = 0 }
        if smoothedMid < 0.05 { smoothedMid = 0 }
        if smoothedTreble < 0.05 { smoothedTreble = 0 }

        self.currentLevels = (
            bass: CGFloat(smoothedBass),
            mid: CGFloat(smoothedMid),
            treble: CGFloat(smoothedTreble)
        )
    }

    /// 瞬态重拍冲击力计算：平稳背景输出 0.0，仅在显著超出背景的突发重击点爆发
    private static func calculateBeatImpulse(raw: Float, avg: Float, peak: Float, multiplier: Float, minThreshold: Float, power: Float) -> Float {
        let threshold = max(avg * multiplier, minThreshold)
        guard raw > threshold else { return 0.0 }
        let headroom = max(0.04, peak - threshold)
        let normalized = min(1.0, (raw - threshold) / headroom)
        return pow(normalized, power)
    }

    private func decayLevels() {
        smoothedBass = max(0, smoothedBass * 0.68 - 0.04)
        smoothedMid = max(0, smoothedMid * 0.70 - 0.04)
        smoothedTreble = max(0, smoothedTreble * 0.68 - 0.04)

        if smoothedBass < 0.05 { smoothedBass = 0 }
        if smoothedMid < 0.05 { smoothedMid = 0 }
        if smoothedTreble < 0.05 { smoothedTreble = 0 }

        self.currentLevels = (
            bass: CGFloat(smoothedBass),
            mid: CGFloat(smoothedMid),
            treble: CGFloat(smoothedTreble)
        )
    }

    /// 播放暂停或切歌时归零重置
    func reset() {
        os_unfair_lock_lock(&sampleBufferLock)
        activeTapID = nil
        hasNewSamples = false
        os_unfair_lock_unlock(&sampleBufferLock)
        smoothedBass = 0
        smoothedMid = 0
        smoothedTreble = 0
        avgBass = 0
        avgMid = 0
        avgTreble = 0
        isBandTrackerInitialized = false
        isAudioActive = false
        currentLevels = (0, 0, 0)
    }
}
