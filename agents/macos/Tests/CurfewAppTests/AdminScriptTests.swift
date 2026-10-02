@testable import CurfewApp
import Testing

@Suite struct AdminScriptTests {
    @Test func plainPath() {
        #expect(AdminScript.source(tool: "/Applications/Curfew.app/Contents/Resources/curfew", action: .install)
            == #"do shell script "'/Applications/Curfew.app/Contents/Resources/curfew' install" with administrator privileges"#)
    }

    @Test func quotesSpacesQuotesAndBackslashes() {
        let tool = #"/Users/o'neil/My "Apps"/Cur\few.app/Contents/Resources/curfew"#
        #expect(AdminScript.shellQuoted(tool) == #"'/Users/o'\''neil/My "Apps"/Cur\few.app/Contents/Resources/curfew'"#)
        #expect(AdminScript.source(tool: tool, action: .uninstall)
            == #"do shell script "'/Users/o'\\''neil/My \"Apps\"/Cur\\few.app/Contents/Resources/curfew' uninstall" with administrator privileges"#)
    }

    @Test func shellMetacharactersStayInsideTheQuotes() {
        let quoted = AdminScript.shellQuoted("/tmp/$(reboot);`id`&x")
        #expect(quoted == "'/tmp/$(reboot);`id`&x'")
    }

    @Test func eachActionIsOneSubcommand() {
        #expect(PrivilegedAction.allCases.map(\.rawValue) == ["install", "uninstall", "restart"])
        #expect(AdminScript.source(tool: "/x", action: .restart).hasSuffix(#"'/x' restart" with administrator privileges"#))
    }
}
