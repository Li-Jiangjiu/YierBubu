import Foundation

public struct KeyGeometry: Sendable {
    public let code: UInt16
    public let label: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
}

/// Fixed physical Mac ANSI QWERTY layout. IME output is deliberately not read.
public enum KeyboardLayout {
    public static let title = "Mac · ANSI QWERTY"
    public static let keys: [KeyGeometry] = {
        var result: [KeyGeometry] = []
        func row(_ y: Double, _ height: Double, _ entries: [(UInt16, String, Double)]) {
            var x = 30.0
            for (code, label, units) in entries {
                let width = units * 29 - 3
                result.append(KeyGeometry(code: code, label: label, x: x, y: y, width: width, height: height))
                x += units * 29
            }
        }
        row(222, 16, [(53,"esc",1.5),(122,"F1",1),(120,"F2",1),(99,"F3",1),(118,"F4",1),
                      (96,"F5",1),(97,"F6",1),(98,"F7",1),(100,"F8",1),(101,"F9",1),(109,"F10",1),
                      (103,"F11",1),(111,"F12",1)])
        row(244, 21, [(50,"`",1),(18,"1",1),(19,"2",1),(20,"3",1),(21,"4",1),(23,"5",1),
                      (22,"6",1),(26,"7",1),(28,"8",1),(25,"9",1),(29,"0",1),(27,"−",1),
                      (24,"=",1),(51,"delete",1.5)])
        row(270, 21, [(48,"tab",1.5),(12,"Q",1),(13,"W",1),(14,"E",1),(15,"R",1),(17,"T",1),
                      (16,"Y",1),(32,"U",1),(34,"I",1),(31,"O",1),(35,"P",1),(33,"[",1),
                      (30,"]",1),(42,"\\",1)])
        row(296, 21, [(57,"caps",1.75),(0,"A",1),(1,"S",1),(2,"D",1),(3,"F",1),(5,"G",1),
                      (4,"H",1),(38,"J",1),(40,"K",1),(37,"L",1),(41,";",1),(39,"'",1),(36,"return",1.75)])
        row(322, 21, [(56,"shift",2.25),(6,"Z",1),(7,"X",1),(8,"C",1),(9,"V",1),(11,"B",1),
                      (45,"N",1),(46,"M",1),(43,",",1),(47,".",1),(44,"/",1),(60,"shift",2.25)])
        row(348, 24, [(59,"ctrl",1),(58,"opt",1),(55,"cmd",1.25),(49,"space",5.25),
                      (54,"cmd",1.25),(61,"opt",1),(62,"ctrl",1)])
        result.append(KeyGeometry(code: 123,label:"←",x:378,y:348,width:26,height:24))
        result.append(KeyGeometry(code: 126,label:"↑",x:407,y:348,width:26,height:11))
        result.append(KeyGeometry(code: 125,label:"↓",x:407,y:361,width:26,height:11))
        result.append(KeyGeometry(code: 124,label:"→",x:436,y:348,width:26,height:24))
        return result
    }()
    private static let index = Dictionary(uniqueKeysWithValues: keys.map { ($0.code, $0) })
    public static func key(for code: UInt16) -> KeyGeometry? { index[code] }
}
