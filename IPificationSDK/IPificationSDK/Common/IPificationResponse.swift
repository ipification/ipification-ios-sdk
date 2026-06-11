//
//  IPificationResponse.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation

/// Identifies the serialization format of a generic SDK response.
public enum ResponseType{
    /// JavaScript Object Notation.
    case json
    /// Extensible Markup Language.
    case xml
    /// Unstructured text.
    case string
    
}

/// A generic response container retained for compatibility with existing integrations.
public class IPificationResponse{
    /// The response payload in its original representation.
    var data : Any
    /// The serialization format of the stored response data.
    public var responseType: ResponseType
    init(responseType: ResponseType, data : Any) {
        self.responseType = responseType
        self.data = data
    }
    /// Returns the response payload in its original representation.
    public func getData() -> Any{
        return data
    }
}
