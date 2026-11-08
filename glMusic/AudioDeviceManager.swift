//
//  AudioDeviceManager.swift
//  glMusic
//
//  Created by go love on 11/7/26.
//

import CoreAudio
import Foundation
import SwiftUI

/// 音频输出设备信息
struct AudioOutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transportType: UInt32

    var isBuiltIn: Bool {
        transportType == kAudioDeviceTransportTypeBuiltIn
    }

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    var isDisplay: Bool {
        transportType == kAudioDeviceTransportTypeDisplayPort ||
        transportType == kAudioDeviceTransportTypeHDMI ||
        name.localizedCaseInsensitiveContains("Display") ||
        name.localizedCaseInsensitiveContains("DELL") ||
        name.localizedCaseInsensitiveContains("LG") ||
        name.localizedCaseInsensitiveContains("BenQ") ||
        name.localizedCaseInsensitiveContains("ASUS")
    }

    var isAirPlay: Bool {
        transportType == kAudioDeviceTransportTypeAirPlay || name.localizedCaseInsensitiveContains("AirPlay")
    }

    /// 智能设备图标
    var iconName: String {
        let lower = name.lowercased()
        if lower.contains("airpods max") {
            return "airpodsmax"
        } else if lower.contains("airpods pro") {
            return "airpodspro"
        } else if lower.contains("airpods") {
            return "airpods"
        } else if isBluetooth || lower.contains("headphone") || lower.contains("耳机") {
            return "headphones"
        } else if isDisplay {
            return "display"
        } else if isAirPlay {
            return "airplayaudio"
        } else if isBuiltIn {
            return "laptopcomputer"
        } else if transportType == kAudioDeviceTransportTypeUSB {
            return "hifispeaker.fill"
        }
        return "speaker.wave.2.fill"
    }

    /// 类型描述文本
    var transportDescription: String {
        if isAirPlay { return "隔空播放".localized }
        if isDisplay { return "外接显示器".localized }
        if isBluetooth { return "蓝牙 / 耳机".localized }
        if isBuiltIn { return "内置扬声器".localized }
        if transportType == kAudioDeviceTransportTypeUSB { return "USB 音频设备".localized }
        return "音频设备".localized
    }
}

/// 系统音频输出设备管理器 (基于 CoreAudio)
@Observable
final class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    var outputDevices: [AudioOutputDevice] = []
    var currentDeviceID: AudioDeviceID = 0

    var currentDevice: AudioOutputDevice? {
        outputDevices.first(where: { $0.id == currentDeviceID })
    }

    /// 按钮显示的智能图标：当连接外接耳机/AirPods时直观显示耳机图标，其它情况显示隔空播放/音频设备图标
    var buttonIconName: String {
        if let current = currentDevice {
            if current.isBluetooth ||
               current.name.lowercased().contains("airpods") ||
               current.name.lowercased().contains("headphone") ||
               current.name.contains("耳机") {
                return current.iconName
            }
        }
        return "airplayaudio"
    }

    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    private init() {
        refreshDevices()
        setupHardwareListeners()
    }

    deinit {
        removeHardwareListeners()
    }

    /// 刷新并获取系统所有可用的音频输出设备
    func refreshDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )
        guard status == noErr else { return }

        let deviceCount = Int(propertySize / UInt32(MemoryLayout<AudioDeviceID>.size))
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        guard status == noErr else { return }

        var list: [AudioOutputDevice] = []
        for id in deviceIDs {
            // 检查是否有有效输出通道
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
            guard status == noErr && streamSize > 0 else { continue }

            // 设备名称
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let nameStatus = AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name)
            let devName = (nameStatus == noErr && name != nil) ? (name!.takeRetainedValue() as String) : "Unknown"

            // 设备 UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let uidStatus = AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &uid)
            let devUID = (uidStatus == noErr && uid != nil) ? (uid!.takeRetainedValue() as String) : ""

            // 传输类型
            var transAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transType: UInt32 = 0
            var transSize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(id, &transAddress, 0, nil, &transSize, &transType)

            list.append(AudioOutputDevice(id: id, uid: devUID, name: devName, transportType: transType))
        }

        // 当前默认输出设备 ID
        var defaultID: AudioDeviceID = 0
        var defSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defAddress,
            0,
            nil,
            &defSize,
            &defaultID
        )

        withAnimation(.easeInOut(duration: 0.15)) {
            self.outputDevices = list
            self.currentDeviceID = defaultID
        }
    }

    /// 切换系统音频默认输出设备
    func selectDevice(_ device: AudioOutputDevice) {
        var devID = device.id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &devID
        )

        if status == noErr {
            withAnimation(.easeInOut(duration: 0.15)) {
                self.currentDeviceID = device.id
            }
        }
    }

    /// 打开 macOS 系统的声音偏好设置面板
    func openSystemSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - CoreAudio Listeners

    private func setupHardwareListeners() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }
        self.listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main,
            block
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            block
        )
    }

    private func removeHardwareListeners() {
        if let block = listenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesAddress,
                DispatchQueue.main,
                block
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                DispatchQueue.main,
                block
            )
            self.listenerBlock = nil
        }
    }
}
