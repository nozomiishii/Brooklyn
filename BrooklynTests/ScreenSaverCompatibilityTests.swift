import AppKit
import Darwin
import ObjectiveC
import ScreenSaver
import XCTest

@MainActor
final class ScreenSaverCompatibilityTests: XCTestCase {
    func test基底クラスの継承関係が変わっていない() throws {
        let classNames = [
            "ScreenSaverExtension",
            "ScreenSaverViewController",
            "ScreenSaverConfigurationViewController",
        ]

        for className in classNames {
            let runtimeClass = try XCTUnwrap(NSClassFromString(className) as? NSObject.Type, className)
            let expectedSuperclass: AnyClass = if className == "ScreenSaverExtension" {
                NSObject.self
            } else {
                NSViewController.self
            }

            XCTAssertTrue(runtimeClass.isSubclass(of: expectedSuperclass), className)
        }
    }

    func test利用するメソッドの型が変わっていない() throws {
        let methods = [
            MethodSignature(className: "ScreenSaverExtension", selectorName: "init", returnType: "@"),
            MethodSignature(
                className: "ScreenSaverViewController",
                selectorName: "initWithNibName:bundle:",
                returnType: "@",
                argumentTypes: ["@", "@"],
            ),
            MethodSignature(
                className: "ScreenSaverViewController",
                selectorName: "initWithCoder:",
                returnType: "@",
                argumentTypes: ["@"],
            ),
            MethodSignature(className: "ScreenSaverViewController", selectorName: "loadView"),
            MethodSignature(className: "ScreenSaverViewController", selectorName: "viewDidAppear"),
            MethodSignature(className: "ScreenSaverViewController", selectorName: "viewWillDisappear"),
            MethodSignature(className: "ScreenSaverConfigurationViewController", selectorName: "loadView"),
            MethodSignature(className: "ScreenSaverConfigurationViewController", selectorName: "configureSheetDidEnd"),
        ]

        for method in methods {
            try assertCompatibleMethodSignature(
                className: method.className,
                selectorName: method.selectorName,
                returnType: method.returnType,
                argumentTypes: method.argumentTypes,
            )
        }
    }

    private struct MethodSignature {
        let className: String
        let selectorName: String
        var returnType = "v"
        var argumentTypes: [String] = []
    }

    private func assertCompatibleMethodSignature(
        className: String,
        selectorName: String,
        returnType: String,
        argumentTypes: [String],
    ) throws {
        let context = "\(className).\(selectorName)"
        let runtimeClass = try XCTUnwrap(NSClassFromString(className), context)
        let method = try XCTUnwrap(class_getInstanceMethod(runtimeClass, NSSelectorFromString(selectorName)), context)
        let actualReturnType = try XCTUnwrap(method_copyReturnType(method), context)
        defer { free(actualReturnType) }

        XCTAssertEqual(String(cString: actualReturnType), returnType, context)

        let allArgumentTypes = ["@", ":"] + argumentTypes
        XCTAssertEqual(method_getNumberOfArguments(method), UInt32(allArgumentTypes.count), context)

        for (index, expectedType) in allArgumentTypes.enumerated() {
            let actualType = try XCTUnwrap(method_copyArgumentType(method, UInt32(index)), context)
            defer { free(actualType) }
            XCTAssertEqual(String(cString: actualType), expectedType, "\(context) 引数 \(index)")
        }
    }
}
