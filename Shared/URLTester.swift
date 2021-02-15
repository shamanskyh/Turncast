//
//  URLTester.swift
//  Turncast
//
//  Created by Harry Shamansky on 2/9/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation

extension URL {
    func verify(completion: @escaping (_ valid: Bool) -> ()) {
        var request = URLRequest(url: self)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse, error == nil {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        })
        task.resume()
    }
}
