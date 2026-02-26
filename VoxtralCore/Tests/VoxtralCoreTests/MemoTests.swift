import Testing
import Foundation
@testable import VoxtralCore

@Suite("Memo")
struct MemoTests {

    @Test("displayTitle returns first line when short")
    func displayTitleShortFirstLine() {
        let memo = Memo(audioFileName: "test.m4a", transcript: "Hello world")
        #expect(memo.displayTitle == "Hello world")
    }

    @Test("displayTitle truncates at word boundary around 60 chars")
    func displayTitleTruncatesLongLine() {
        let longText = "This is a very long transcript that exceeds sixty characters and should be truncated properly"
        let memo = Memo(audioFileName: "test.m4a", transcript: longText)
        #expect(memo.displayTitle.hasSuffix("..."))
        #expect(memo.displayTitle.count <= 64) // 60 chars + "..."
    }

    @Test("displayTitle uses only first line of multiline transcript")
    func displayTitleMultiline() {
        let memo = Memo(audioFileName: "test.m4a", transcript: "First line\nSecond line\nThird line")
        #expect(memo.displayTitle == "First line")
    }

    @Test("displayTitle returns 'New Memo' when transcript is nil")
    func displayTitleNilTranscript() {
        let memo = Memo(audioFileName: "test.m4a", transcript: nil)
        #expect(memo.displayTitle == "New Memo")
    }

    @Test("displayTitle returns 'New Memo' when transcript is empty")
    func displayTitleEmptyTranscript() {
        let memo = Memo(audioFileName: "test.m4a", transcript: "")
        #expect(memo.displayTitle == "New Memo")
    }

    @Test("formattedDuration formats minutes and seconds")
    func formattedDuration() {
        let memo = Memo(audioFileName: "test.m4a")
        memo.duration = 125 // 2 min 5 sec
        #expect(memo.formattedDuration == "2Min. 5Sec.")
    }

    @Test("formattedDuration with zero duration")
    func formattedDurationZero() {
        let memo = Memo(audioFileName: "test.m4a")
        memo.duration = 0
        #expect(memo.formattedDuration == "0Min. 0Sec.")
    }

    @Test("audioFileURL is inside audioDirectory")
    func audioFileURLPath() {
        let memo = Memo(audioFileName: "recording.m4a")
        let url = memo.audioFileURL
        #expect(url.lastPathComponent == "recording.m4a")
        #expect(url.deletingLastPathComponent() == Memo.audioDirectory)
    }
}
