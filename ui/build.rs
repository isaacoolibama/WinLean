fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        let mut resource = winresource::WindowsResource::new();
        resource
            .set_icon("assets/winlean.ico")
            .set("ProductName", "WinLean")
            .set(
                "FileDescription",
                "WinLean - Windows cleanup and optimization",
            )
            .set("OriginalFilename", "winlean.exe");
        resource
            .compile()
            .expect("failed to compile Windows resources");
    }
}
