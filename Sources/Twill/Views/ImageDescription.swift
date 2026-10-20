/// The fallback is erased only when concrete image composition reaches the runtime.
struct ImageDescription {
    let image: Image
    let size: CellSize
    let contentMode: ImageContentMode
    let fallback: any View
}
