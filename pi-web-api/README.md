# PI Web API Utilities

Snippets and utilities for working with the AVEVA PI Web API.

---

## GetWebId_NodeRed_flow.json

A **Node-RED** function node that generates a PI Web API **WebID** from an Asset Framework (AF) path, without needing to make an HTTP call to the PI Web API server.

This is useful when you already know the AF path and want to construct the WebID client-side for use in subsequent PI Web API requests.

### How it works

The function implements the PI Web API WebID v1 encoding scheme for AF Elements:

1. Strips the leading `\\` from the AF path
2. Uppercases and Base64-encodes the path
3. Prepends the type prefix (`P1AbE`) to produce the final WebID

### Usage in Node-RED

1. Open Node-RED and navigate to the target flow
2. Go to **Menu** > **Import** > paste the contents of `GetWebId_NodeRed_flow.json`
3. Wire a node that sets `msg.payload` to an AF path (e.g. `\\myafserver\mydatabase\myelement|myattribute`) into the **webid** function node
4. The output `msg.payload` will contain:

```json
{
  "webid": "P1AbE<base64encodedpath>",
  "afpath": "MYAFSERVER\\MYDATABASE\\MYELEMENT|MYATTRIBUTE"
}
```

### Example

| Input (`msg.payload`) | Output WebID prefix |
|-----------------------|-------------------|
| `\\myserver\mydb\myelement` | `P1AbE...` |
| `\\myserver\mydb\myelement\|myattribute` | `P1AbE...` |

### Notes

- This generates WebIDs for **AF Elements** only (object marker `E`). Other object types (PI Points, AF Attributes, etc.) use different markers and are not covered by this snippet.
- The generated WebID matches what the PI Web API server would return for the same path — it does not require a round-trip to the server.
- This is a **Node-RED** flow snippet. To use the logic in another environment, adapt the JavaScript from the `func` field in the JSON file.
