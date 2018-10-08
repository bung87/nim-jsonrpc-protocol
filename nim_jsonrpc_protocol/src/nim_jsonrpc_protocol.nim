import strutils
import sequtils
import macros
import typetraits
import json

type 
  GRequest*[I:int|string,P]  = object
    jsonrpc:string
    `method`: string
    id : I
    params:P # omitted

  # BatchRequest = seq[Request]
  Request*[T]  = concept o ,type M
    o.jsonrpc is string
    o.method is string
    type TransposedType = stripGenericParams(M)[T]
    o is TransposedType
    o.id is string or o.id is SomeNumber
    o.params is T # omitted

  Response* = concept o
    o.jsonrpc is string
    o.method is string
    o.id is string or o.id is SomeNumber

  SuccessResponse* = concept o of Response
    o.result is string

  Error*[T]  = concept o
    o.code  is SomeNumber
    o.message is string
    o.data is T # omitted

  ErrorResponse* = concept o of Response
    o.error is Error

  ServerError* = range[32000..32099]

proc camelCase(label: string): string =
  let tokens = label.split(" ")
  result = tokens[0].toLowerAscii & tokens[1..^1].mapIt(capitalizeAscii(it)).join("")
  
macro errdef*(name: untyped, val: typed):untyped =
  let constName = ident(camelCase(name.repr))
  # let cmt = newCommentStmtNode(name.repr)
  quote:
    const `constName` *  = `val` 

# http://xmlrpc-epi.sourceforge.net/specs/rfc.fault_codes.php

errdef(Parse Error,-32700)
errdef(Invalid Request,-32600)
errdef(Method Not Found,-32601)
errdef(Invalid Params,-32602)
errdef(Internal Error,-32603)

# Defined by JSON RPC
# https://microsoft.github.io/language-server-protocol/specification
errdef(Server Error Start,-32099)
errdef(Server Error End,-32000)
errdef(Server Not Initialized,-32002)
errdef(Unknown Error Code,-32001)

proc initGRequest*[P:int|string,T](id:P,`method`:string,params:T,jsonrpc="2.0"):GRequest[P,T] =
  result.id = id
  result.method = `method`
  result.jsonrpc = jsonrpc
  result.params = params

proc jRequest*[T,P:int|string](id:P,`method`:string,params:openarray[T],jsonrpc="2.0"):JsonNode{.noInit.} =
  result = newJObject()
  result["id"] = %id
  result["method"] = %`method`
  result["jsonrpc"] = %jsonrpc
  result["params"] = %params

proc jRequest*[P:int|string](id:P,`method`:string,jsonrpc="2.0"):JsonNode{.noInit.} =
  result = newJObject()
  result["id"] = %id
  result["method"] = %`method`
  result["jsonrpc"] = %jsonrpc

template gRequest*[P:int|string](id:P,`method`:string,jsonrpc="2.0",params: untyped): untyped  =
  let result = newJObject()
  result["id"] = %id
  result["method"] = %`method`
  result["jsonrpc"] = %jsonrpc
  result["params"] = %*params
  result

when isMainModule:
  assert parseError == -32700
  type RP = object
    subtrahend:int
    bar:string
  
  let rp = RP(subtrahend:1,bar:"baz")
  let c = GRequest[int,RP](id:1,`method`:"aaa",params:rp,jsonrpc:"2.0")
  const ec = """{"jsonrpc":"2.0","method":"aaa","id":1,"params":{"subtrahend":1,"bar":"baz"}}"""
  assert $(%c) == ec

  let f = initGRequest(id=1,`method`="aaa",params=rp)
  assert $(%f) == ec

  let d = jRequest(id = 1,`method`="aaa",params = ["a","b"])
  const dc = """{"id":1,"method":"aaa","jsonrpc":"2.0","params":["a","b"]}"""
  assert $d == dc
  let e = jRequest(id = 1,`method`="aaa")

  
  echo gRequest(id = 1,`method`="aaa",params ={"name": "Isaac", "books": ["Robot Dreams",1]})

