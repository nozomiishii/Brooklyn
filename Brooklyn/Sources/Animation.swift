import Foundation

/// All 75 Brooklyn animations from the original Apple event.
enum Animation: String, CaseIterable, Identifiable {
    case appleBits
    case auroraBorealis
    case avatarTissue
    case ballPit
    case binary
    case bits
    case bloomingRoses
    case bluePipes
    case blueSand
    case cases
    case cells
    case cityLife
    case colorfulSunset
    case connectivity
    case crescentMoon
    case cubicMess
    case cuphead
    case cuphead2
    case cursor
    case defragmentation
    case doodle
    case dots
    case fadingPieces
    case fangs
    case fruitNinja
    case fullMoon
    case geometricShapes
    case glow
    case goldenBarbs
    case gummyWorms
    case hills
    case inception
    case juicy
    case kaleidoscope
    case layers
    case leaf
    case lines
    case magnify
    case monochrome
    case nature
    case neon
    case noiseStripes
    case oldScreen
    case original
    case paintbrush
    case paintRivers
    case pangea
    case penrose
    case picasso
    case playDoh
    case polarPeak
    case riverNoir
    case runningInGrass
    case sapphire
    case shards
    case shelves
    case snakes
    case soundSpectrum
    case splash
    case stripes
    case sulleysFur
    case sunset
    case theRoom
    case tissue
    case trapezium
    case unstablePipes
    case volumetric
    case warp
    case watercolors
    case waterDrops
    case wet
    case yolk
    case zebra
    case zelda
    case zoetrope

    var id: String {
        rawValue
    }

    /// Display name derived from the raw value (e.g., "ballPit" → "Ball Pit").
    var displayName: String {
        let spaced = rawValue.replacingOccurrences(
            of: "([a-z])([A-Z0-9])",
            with: "$1 $2",
            options: .regularExpression
        )
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    /// URL to the MP4 file within the bundle.
    func videoURL(in bundle: Bundle) -> URL? {
        bundle.url(forResource: rawValue, withExtension: "mp4", subdirectory: "Animations")
    }
}
