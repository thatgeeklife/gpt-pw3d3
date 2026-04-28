# M24.6 Rebuild Wrapper

Each authored scene path row now includes a **Rebuild Wrapper** button.

Use it when:

- the wrapper `.tscn` exists but appears stale
- the wrapper metadata is missing
- the validation report says the wrapper needs to be rebuilt
- you updated the imported `.gltf`/`.glb` and want the wrapper regenerated

The button only works for generated `_wrapper.tscn` paths inside `GameProject`.

Direct `.tscn` scenes are intentionally left alone, and raw `.gltf/.glb` paths should be selected through Browse so the import/wrap flow can run.
