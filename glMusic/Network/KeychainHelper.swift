//
//  KeychainHelper.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import Foundation
import Security

/// macOS 原生钥匙串安全存取工具 (用于加密安全隔离网易云登录凭据 Cookie，杜绝明文泄露)
enum KeychainHelper {
    private static let service = "com.golove.glMusic"
    private static let cookieAccount = "netease_cookie"

    /// 保存 Cookie 到系统 Keychain
    static func saveCookie(_ cookie: String) {
        guard let data = cookie.data(using: .utf8) else { return }
        deleteCookie()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cookieAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    /// 从系统 Keychain 读取 Cookie
    static func loadCookie() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cookieAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 从系统 Keychain 移除 Cookie
    static func deleteCookie() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cookieAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
