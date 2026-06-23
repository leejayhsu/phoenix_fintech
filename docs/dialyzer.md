# Dialyzer and editor support

This app uses Dialyxir so local development and CI-style checks can run Dialyzer with:

```sh
mix dialyzer
```

`mix precommit` also runs Dialyzer after compilation, unused dependency checks, and formatting.

## Where specs add the most value

The first pass focuses on public context APIs because those functions define the business-facing contracts used by LiveViews, controllers, and other contexts. Schema structs expose a `t()` type so context specs can describe return values without falling back to untyped maps.

## HEEx templates and ElixirLS

Dialyzer analyzes compiled BEAM modules and specs. Phoenix HEEx templates are compiled into functions, so Dialyzer can catch type issues that survive template compilation, but it is not a dedicated template language server and does not provide assign-level autocomplete by itself.

ElixirLS does use Dialyzer artifacts for richer symbol indexing and diagnostics. In practice, enabling Dialyzer in ElixirLS can improve code navigation/autocomplete for modules, functions, types, and callbacks, while HEEx-specific autocomplete still depends on the editor's HEEx support and Phoenix component metadata such as `attr` and `slot` declarations.

For VS Code + ElixirLS, enable Dialyzer in your user or workspace settings if it is disabled:

```json
{
  "elixirLS.dialyzerEnabled": true
}
```
