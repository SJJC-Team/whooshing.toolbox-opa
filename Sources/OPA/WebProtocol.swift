//
//  WebProtocol.swift
//  whooshing.toolbox-opa
//
//  Created by CLWang on 2/3/26.
//


import ErrorHandle
import NIOCore
import Logging
import LoggingAdvanced
import NIOAdvanced
import AsyncHTTPClient

/// HTTP 请求协议类型 (HTTP/HTTPS)
        public enum WebProtocol: String, Sendable {
            case http
            case https
        }