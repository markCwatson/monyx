# TFLite on iOS — Symbol Stripping Workaround

## The problem

The `tflite_flutter` plugin uses Dart FFI (`dlsym(RTLD_DEFAULT, "TfLiteModelCreate")`) to call TensorFlowLiteC at runtime. On iOS, TensorFlowLiteC v2.12.0 ships as a **static library** for device (arm64) but a **dynamic framework** for the simulator. When statically linked, no Swift/ObjC code in the app references the TFLite C symbols directly — only Dart does, at runtime. The iOS linker and strip tool can't see runtime `dlsym` calls, so they dead-strip and remove the symbols from the release binary. The result: TFLite works on the simulator (dynamic framework → symbols always available) but crashes on physical devices with:

```
Failed to lookup symbol 'TfLiteModelCreate': dlsym(RTLD_DEFAULT, TfLiteModelCreate): symbol not found
```

## The fix (three parts)

All three are required. Removing any one of them causes the symbols to be stripped.

### 1. `ios/Runner/KeepTfLiteSymbols.m`

A native ObjC file that references TFLite C API functions with `__attribute__((used))`. This creates compile-time references so the linker pulls the symbols from the static library into the binary. The function is never called — its existence is what matters.

### 2. `DEAD_CODE_STRIPPING = NO` on the Runner target

Set via the Podfile `post_install` block (not globally on pods). Prevents the linker from removing "unreachable" code paths within the static library.

### 3. `STRIP_STYLE = non-global` on the Runner target

Also set via Podfile `post_install`. After linking, Xcode runs `strip` on the binary. The default strip style removes global symbols. `non-global` keeps them, so `dlsym()` can find `TfLiteModelCreate` at runtime.

**Important:** These settings must only be applied to the **Runner target**, not to all pod targets. Applying `STRIP_STYLE` globally (e.g., in `installer.pods_project.targets`) causes pod frameworks like `objective_c.framework` to retain simulator platform tags, which fails App Store validation.

## What didn't work

| Approach                                                                   | Why it failed                                                                                                          |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `DynamicLibrary.open('TensorFlowLiteC.framework/TensorFlowLiteC')` in Dart | Works on simulator (dynamic framework) but the framework file doesn't exist on device (static lib)                     |
| `-Wl,-u,_TfLiteModelCreate` in `OTHER_LDFLAGS`                             | Tells the linker the symbol is needed, but post-link `strip` still removes it                                          |
| `STRIP_STYLE = non-global` on all targets via Podfile                      | Preserves symbols but also preserves simulator platform tags in pod frameworks → Xcode distribution validation failure |
