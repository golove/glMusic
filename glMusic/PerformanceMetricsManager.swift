//
//  PerformanceMetricsManager.swift
//  glMusic
//
//  Created by go love on 11/12/26.
//

import Foundation
import MetricKit
import os

/// 线上与开发期真实性能度量管理器 (基于系统级 MetricKit，监控启动耗时、主线程 Hangs、滚动 Hitch 掉帧比率与内存峰值)
final class PerformanceMetricsManager: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    nonisolated static let shared = PerformanceMetricsManager()
    private let logger = Logger(subsystem: "com.golove.glMusic", category: "PerformanceMetrics")

    private override init() {
        super.init()
    }

    nonisolated func startMonitoring() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit 性能监控管道注册成功 (macOS 15 原生度量基线活跃)")
    }

    nonisolated func stopMonitoring() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                logger.info("[MetricKit] 启动首帧耗时分布采样: \(launch.histogrammedTimeToFirstDraw.totalBucketCount) 次")
            }
            if let memory = payload.memoryMetrics {
                logger.info("[MetricKit] 内存峰值基线: \(memory.peakMemoryUsage)")
            }
            if let animation = payload.animationMetrics {
                logger.info("[MetricKit] 滚动 Hitch 掉帧比率: \(animation.scrollHitchTimeRatio)")
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let hangDiagnostics = payload.hangDiagnostics {
                for hang in hangDiagnostics {
                    logger.warning("[MetricKit 警告] 捕获主线程卡顿 (Hang): 持续时间 = \(hang.hangDuration)")
                }
            }
            if let crash = payload.crashDiagnostics {
                logger.error("[MetricKit 错误] 捕获崩溃诊断: 共 \(crash.count) 次")
            }
        }
    }
}
