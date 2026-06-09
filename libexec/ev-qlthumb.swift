// ev-qlthumb — QuickLook 썸네일 생성기 (macOS)
//
// QLThumbnailGenerator로 임의 파일(hwpx/docx/pptx/xlsx/pdf/이미지 등)의 첫 페이지를
// PNG로 저장한다. qlmanage CLI와 달리 모던 QuickLook App Extension(예: Alhangeul의
// hwpx 익스텐션)을 정상적으로 사용한다.
//
// 사용법: ev-qlthumb <file> <out.png> [size]
// 종료코드: 0 성공 / 1 생성 실패 / 2 인자 오류 / 3 타임아웃
//
// ev가 첫 실행 시 `swiftc -O`로 컴파일해 ~/.cache/ev/ev-qlthumb 에 캐시한다.

import Foundation
import QuickLookThumbnailing
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: ev-qlthumb <file> <out.png> [size]\n".data(using: .utf8)!)
    exit(2)
}

let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let size: CGFloat = args.count >= 4 ? CGFloat(Double(args[3]) ?? 1200) : 1200

let request = QLThumbnailGenerator.Request(
    fileAt: inURL,
    size: CGSize(width: size, height: size),
    scale: 1.0,
    representationTypes: .all
)

let sem = DispatchSemaphore(value: 0)
var ok = false

QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (rep, err) in
    defer { sem.signal() }
    guard let rep = rep else {
        if let err = err {
            FileHandle.standardError.write("ql error: \(err)\n".data(using: .utf8)!)
        }
        return
    }
    let bitmap = NSBitmapImageRep(cgImage: rep.cgImage)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
    do {
        try data.write(to: outURL)
        ok = true
    } catch {
        FileHandle.standardError.write("write error: \(error)\n".data(using: .utf8)!)
    }
}

if sem.wait(timeout: .now() + 30) == .timedOut {
    FileHandle.standardError.write("timeout\n".data(using: .utf8)!)
    exit(3)
}
exit(ok ? 0 : 1)
