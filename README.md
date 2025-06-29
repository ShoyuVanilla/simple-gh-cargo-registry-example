# simple-gh-cargo-registry-example

This is an example repository for [simple-gh-cargo-registry](https://github.com/ShoyuVanilla/simple-gh-cargo-registry)

Currenty, this repository have a crate [`thiserror`](https://github.com/dtolnay/thiserror) with two versions: `1.0.69` and `2.0.12`.

You can test this with something like

```toml
# .cargo/config.toml
[registries.foo]
index = "https://github.com/ShoyuVanilla/simple-gh-cargo-registry-example"

# Cargo.toml
# ...omitted
[dependencies]
thiserror = { version = "1", registry = "foo" }
```
