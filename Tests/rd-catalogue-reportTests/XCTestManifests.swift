import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(rd_catalogue_reportTests.allTests),
    ]
}
#endif