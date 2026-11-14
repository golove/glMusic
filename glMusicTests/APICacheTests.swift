import XCTest
@testable import glMusic

private struct TestPayload: Codable, Equatable {
    let id: Int
    let title: String
}

final class APICacheTests: XCTestCase {

    override func setUp() async throws {
        await APICache.shared.clearAll()
    }

    override func tearDown() async throws {
        await APICache.shared.clearAll()
    }

    func testMemoryCacheHitAndExpiration() async {
        let key = "test_key_memory"
        let payload = TestPayload(id: 100, title: "Test Title")

        // 写入 10 秒有效期的缓存
        await APICache.shared.set(key, value: payload, ttl: 10.0)

        // 立即读取应命中
        let cached: TestPayload? = await APICache.shared.get(key)
        XCTAssertEqual(cached, payload)

        // 写入已过期的缓存 (-1秒)
        let expiredKey = "test_key_expired"
        await APICache.shared.set(expiredKey, value: payload, ttl: -1.0)

        let expired: TestPayload? = await APICache.shared.get(expiredKey)
        XCTAssertNil(expired)
    }

    func testRemoveAndClearAll() async {
        let key1 = "test_k1"
        let key2 = "test_k2"
        let p1 = TestPayload(id: 1, title: "P1")
        let p2 = TestPayload(id: 2, title: "P2")

        await APICache.shared.set(key1, value: p1, ttl: 60)
        await APICache.shared.set(key2, value: p2, ttl: 60)

        let read1: TestPayload? = await APICache.shared.get(key1)
        XCTAssertEqual(read1, p1)

        await APICache.shared.remove(key1)
        let readRemoved: TestPayload? = await APICache.shared.get(key1)
        XCTAssertNil(readRemoved)

        // key2 仍然存在
        let read2: TestPayload? = await APICache.shared.get(key2)
        XCTAssertEqual(read2, p2)

        // 清空所有
        await APICache.shared.clearAll()
        let read2AfterClear: TestPayload? = await APICache.shared.get(key2)
        XCTAssertNil(read2AfterClear)
    }
}
