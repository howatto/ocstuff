# MT-URI

## Programming
Requiring `uri` gives you access to two methods:

### parseURI(uri)
Analyze a URI and return its components:
- `scheme`
- `host`
- `port`
- `path`
- `query` - Table of key-value pairs as described by the query string. Numeric values are converted to numbers while `true` and `false` (case-sensitive) are converted to their boolean equivalents. 
- `func` - RPC-specific field, the function to call.
- `args` - RPC-specific field, the arguments to pass. Values are converted identically to `query`.

### callURI(uri)
Process a URI and return a value based on its scheme. Right now only the RPC scheme is supported; calling with it will return a value as if you'd used `rpc.call`.

## RPC URI scheme
The scheme takes two forms, the standard form and the prefixed form.

### Standard form
`rpc://host/func/arg1/arg2/...`

Pretty simple. `host` is the hostname to send the call to, `func` is the function to call, and all following components of the path are the arguments to pass.

### Prefixed form
`rpc-prefix://host/func/arg1/arg2/...`

Same as the standard form, only instead it calls `prefix_func`. Replace `prefix` with the same prefix you'd pass to `rpc.proxy`. For instance, `rpc-bbs` prefixes `func` with `bbs_`. 

## Known issues
- Ports are currently ignored by callURI when using RPC.
- Query strings aren't used by RPC in any capacity. Perhaps they could be used for the final argument if the function expects a table there.
