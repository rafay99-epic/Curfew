enum StrictDecoding {
    static func decode<Codec: UnicodeCodec, Units: Sequence>(_ units: Units, as codec: Codec.Type) -> String?
    where Units.Element == Codec.CodeUnit {
        var iterator = units.makeIterator()
        var decoder = Codec()
        var scalars = String.UnicodeScalarView()
        while true {
            switch decoder.decode(&iterator) {
            case .scalarValue(let scalar): scalars.append(scalar)
            case .emptyInput: return String(scalars)
            case .error: return nil
            }
        }
    }
}
