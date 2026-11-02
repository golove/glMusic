//
//  LoginView.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI
import AppKit

struct LoginView: View {
    var onSuccess: ((UserProfile) -> Void)?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Tab
    enum LoginTab: String, CaseIterable {
        case qrcode = "扫码登录"
        case sms    = "短信登录"
    }
    @State private var selectedTab: LoginTab = .sms

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Spacer()
                Text("登录网易云音乐")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Tab Picker
            Picker("", selection: $selectedTab) {
                ForEach(LoginTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)

            // Content
            switch selectedTab {
            case .qrcode:
                QRLoginContent(onSuccess: onSuccess, dismiss: dismiss)
            case .sms:
                SMSLoginContent(onSuccess: onSuccess, dismiss: dismiss)
            }
        }
        .frame(width: 360, height: 480)
    }
}

// MARK: - QR Code Login

struct QRLoginContent: View {
    var onSuccess: ((UserProfile) -> Void)?
    var dismiss: DismissAction

    @State private var qrKey = ""
    @State private var qrImage: NSImage?
    @State private var statusMessage = "正在生成二维码..."
    @State private var qrExpired = false
    @State private var loginSuccess = false
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            // QR Code
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 200, height: 200)

                if let img = qrImage {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(qrExpired ? 0.3 : 1.0)

                    if qrExpired {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundStyle(.white)
                            Text("已过期")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    }
                } else if !loginSuccess {
                    ProgressView()
                        .controlSize(.large)
                }

                if loginSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                        .background(.white, in: Circle())
                }
            }

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                if loginSuccess {
                    Button("完成") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                } else {
                    Button("刷新二维码") {
                        Task { await generateQR() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!qrExpired && qrImage != nil)

                    Button("取消") {
                        pollingTask?.cancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .task {
            await generateQR()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }

    private func generateQR() async {
        qrImage = nil
        qrExpired = false
        loginSuccess = false
        statusMessage = "正在生成二维码..."
        pollingTask?.cancel()

        do {
            let key = try await NetworkManager.shared.getQRKey()
            qrKey = key

            let base64Str = try await NetworkManager.shared.createQR(key: key)
            let cleaned = base64Str
                .replacingOccurrences(of: "data:image/png;base64,", with: "")
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")

            if let data = Data(base64Encoded: cleaned),
               let image = NSImage(data: data) {
                qrImage = image
            }

            statusMessage = "请用网易云音乐 App 扫码登录"
            pollingTask = Task { await pollStatus() }
        } catch {
            statusMessage = "生成二维码失败，请检查 API 服务是否运行"
            print("QR 生成失败: \(error)")
        }
    }

    private func pollStatus() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }

            do {
                let result = try await NetworkManager.shared.checkQR(key: qrKey)

                switch result.code {
                case 800:
                    statusMessage = "二维码已过期，请点击刷新"
                    qrExpired = true
                    return
                case 801:
                    statusMessage = "请用网易云音乐 App 扫码登录"
                case 802:
                    statusMessage = "已扫码，请在手机上点击确认 ✓"
                case 803:
                    if let cookie = result.cookie {
                        NetworkManager.shared.cookie = cookie
                    }
                    statusMessage = "登录成功！"
                    loginSuccess = true

                    if let profile = try? await NetworkManager.shared.loginStatus() {
                        onSuccess?(profile)
                    }
                    return
                default:
                    break
                }
            } catch {
                // polling error ignored
            }
        }
    }
}

// MARK: - SMS Captcha Login

struct SMSLoginContent: View {
    var onSuccess: ((UserProfile) -> Void)?
    var dismiss: DismissAction

    @State private var phone = ""
    @State private var captcha = ""
    @State private var statusMessage = "输入手机号获取验证码"
    @State private var isSendingCode = false
    @State private var isLoggingIn = false
    @State private var loginSuccess = false
    @State private var codeSent = false
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            // Phone icon
            Image(systemName: "iphone.gen2")
                .font(.system(size: 40))
                .foregroundStyle(.pink.gradient)
                .padding(.bottom, 4)

            // Phone number
            HStack(spacing: 8) {
                Text("+86")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                TextField("手机号码", text: $phone)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 30)

            // Captcha row
            HStack(spacing: 8) {
                TextField("验证码", text: $captcha)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    Task { await sendCode() }
                } label: {
                    if isSendingCode {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 90, height: 36)
                    } else {
                        Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 90, height: 36)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(phone.count < 11 || countdown > 0 || isSendingCode)
            }
            .padding(.horizontal, 30)

            // Status message
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(loginSuccess ? .green : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            // Login / Done button
            if loginSuccess {
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.large)
            } else {
                Button {
                    Task { await login() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoggingIn {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("登录")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .controlSize(.large)
                .padding(.horizontal, 30)
                .disabled(phone.count < 11 || captcha.count < 4 || isLoggingIn)
            }

            Button("取消") {
                countdownTask?.cancel()
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private func sendCode() async {
        isSendingCode = true
        statusMessage = "正在发送验证码..."
        do {
            try await NetworkManager.shared.sendCaptcha(phone: phone)
            codeSent = true
            statusMessage = "验证码已发送到 \(phone)"
            countdown = 60
            countdownTask?.cancel()
            countdownTask = Task {
                while countdown > 0, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled { countdown -= 1 }
                }
            }
        } catch {
            statusMessage = "发送验证码失败: \(error.localizedDescription)"
            print("发送验证码失败: \(error)")
        }
        isSendingCode = false
    }

    private func login() async {
        isLoggingIn = true
        statusMessage = "正在登录..."
        do {
            let cookie = try await NetworkManager.shared.loginWithCaptcha(phone: phone, captcha: captcha)
            if cookie != nil {
                statusMessage = "登录成功！"
                loginSuccess = true
                // 获取用户信息
                if let profile = try? await NetworkManager.shared.loginStatus() {
                    onSuccess?(profile)
                }
            } else {
                statusMessage = "登录失败，请检查验证码是否正确"
            }
        } catch {
            statusMessage = "登录失败: \(error.localizedDescription)"
            print("登录失败: \(error)")
        }
        isLoggingIn = false
    }
}

#Preview {
    LoginView()
}
