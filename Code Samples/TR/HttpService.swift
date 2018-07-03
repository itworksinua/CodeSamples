//
//  DataExchange.swift
//  TransferRoom
//
//  Created by admin on 9/14/17.
//  Copyright © 2017 TransferRoom. All rights reserved.
//

import Foundation
import UIKit
import Alamofire

import Firebase
import FirebaseAuth

typealias complitionDictSuccess = ([[String : Any]]) -> ()
typealias complitionArrSuccess = ([String : Any]) -> ()
typealias complitionObjSuccess = ([String]) -> ()
typealias complitionEmptySuccess = () -> ()
typealias complitionFailed = (String) -> ()

let HTTP_DEBUG_MODE = 1

enum TransferType: Int {
    case all = 0, forLoan, toBuy, forLoanToBuy
}

//public var baseURLConnection: String = "https://tr2api.nexpur-services.com/"
//public var baseURLConnection: String = "https://transferroomapi.nexpur-services.com/"
public var baseURLConnection = "https://api.transferroom.com/"


class HttpService: URLSession {
    
    public var isNetworkReachability = false
    
    public var manager: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        let manager = Alamofire.SessionManager(
            configuration: URLSessionConfiguration.default
        )
        manager.session.configuration.timeoutIntervalForRequest = 20.0
        return manager
    }()
    
    fileprivate var session:SessionManager!
    
    static let instance : HttpService = {
        let instance = HttpService()
        
        return instance
    }()
    
    fileprivate override init() {
        super.init()
        startNetworkReachabilityObserver()
    }
    
    let reachabilityManager = Alamofire.NetworkReachabilityManager(host: "www.google.com")
    
    func startNetworkReachabilityObserver() {
        
        reachabilityManager?.listener = { status in
            switch status {
            case .notReachable:
                self.isNetworkReachability = false
            case .unknown :
                self.isNetworkReachability = true
            case .reachable:
                self.isNetworkReachability = true
            }
        }
        reachabilityManager?.startListening()
        
        self.isNetworkReachability = (self.reachabilityManager?.isReachable)!
    }
    
    // 0
    
    func loginIntoFirebase(_ email:String, _ password:String, failed:@escaping complitionFailed) {
        if self.isNetworkReachability {
            Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
                if error != nil {
                    print(error!.localizedDescription)
                    failed(error!.localizedDescription)
                    if self.isNetworkReachability {
                        Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
                            if error != nil {
                                print(error!.localizedDescription)
                                failed(error!.localizedDescription)
                            }
                        }
                    } else {
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
                    }
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 1
    func authenticateUser(_ login:String, password:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["username":login,"password":password,"grant_type": "password"]
        
        let endpoint: String = baseURLConnection + "token"
        
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: URLEncoding.default)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String:Any] {
                                AuthInfo.instance.accessToken = result["access_token"] as! String
                                AuthInfo.instance.tokenType = result["token_type"] as! String
                                AuthInfo.instance.refreshToken = result["refresh_token"] as! String
                                
                                AuthInfo.instance.userPassword = password
                                AuthInfo.instance.userLogin = login
                                
                                self.loginIntoFirebase(login, password, failed: failed)
                                
                                self.getCurrentUserInfo(success: success, failed: failed)
                            } else {
                                failed("\(response)")
                            }
                        default:
                            print("error with response status: \(status)")
                            print(response.result.value ?? "Empty value")
                            if let errorDict = response.result.value as? [String:String] {
                                if errorDict["error_description"] != nil {
                                    failed("\(String(describing: errorDict["error_description"]!))")
                                    return
                                }
                            }
                            failed("Login was failed")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 2
    func refreshToken(_ success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["refresh_token":AuthInfo.instance.refreshToken!,"grant_type": "refresh_token"]
        
        let endpoint: String = baseURLConnection + "token"
        
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: URLEncoding.default)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String:Any] {
                                AuthInfo.instance.accessToken = result["access_token"] as! String
                                AuthInfo.instance.tokenType = result["token_type"] as! String
                                AuthInfo.instance.refreshToken = result["refresh_token"] as! String
                                
                                self.loginIntoFirebase(AuthInfo.instance.userLogin!, AuthInfo.instance.userPassword!, failed: failed)
                                
                                self.getCurrentUserInfo(success: success, failed: failed)
                            } else {
                                failed("\(response)")
                            }
                        default:
                            print("error with response status: \(status)")
                            failed("Error is \(response)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 3
    func getAuthorization(_ fields : String..., success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["field1":"field1Value","field2": "field2Value"]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Auth/authorize"
        
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            AuthInfo.instance.userName = "Test Account"
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("Error is \(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
         
        }
    }
    
    // 4
    func getMySquadPlayersList(transferId typeId : Int, searchWord: String, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["transferType": typeId.description, "keyWord":searchWord] as [String : String]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetMySquad?"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 5
    func getMySquadSelectPlayer(playerId : String, success:@escaping complitionArrSuccess, failed:@escaping complitionFailed) {
        
        let parameters:Parameters = ["playerId": playerId]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetMySquadPlayerProfile"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String : Any] {
                                success(result)
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                            break
                            
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                        
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
         
        }
    }
    
    // 6
    func updateMySquadPlayerProfile(player: SelectedPlayer, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters  =  ["playerId":player.playerId,
                            "transferType":player.transfer!.transferTypeId,
                            "sellOn":player.transfer!.sellOn,
                            "askingPrice":player.transfer!.askingPrice,
                            "monthlyLoanFee":player.transfer!.monthlyLoanFee,
                            "currencyId":player.currencyId,
                            "loanPriceUponRequest": player.transfer!.loanPriceUponRequest,
                            "salePriceUponRequest":player.transfer!.sellPriceUponRequest] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/MySquadPlayerProfileUpdate"
        
        print(endpoint)
        print(headers)
        print(parameters)
        
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("Data not saved!")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 7
    func searchPlayer(_ keyWord: String, filter:Filter, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let parameters: [String: Any] =
            ["keyWord":keyWord as Any,
             "positionsIds":filter.positionsIds.count > 0 ?
                ParseManager.parseArrayToString(filter.positionsIds) : "NULL",
             "leaguesIds":filter.leaguesIds.count > 0 ?
                ParseManager.parseSetToString(filter.leaguesIds) : "NULL",
             "clubsIds":filter.clubsIds,
             "nationalitiesIds":filter.nationalitiesIds,
             "minPrice":filter.minPrice as Any,
             "maxPrice":filter.maxPrice as Any,
             "transferTypeId":filter.transferTypeId as Any,
             "contractExpiry":filter.contractExpiry,
             "pageNumber":filter.pageNumber as Any,
             "minAge":filter.minAge as Any,
             "maxAge":filter.maxAge as Any,
             "isOrder":filter.isOrder as Any,
             "orderValue":filter.orderValue ?? "NULL",
             "orderType": filter.orderType as Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPlayerSearchResults"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 8
    func getPlayerPositon(_ success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetAllPositionPlayerRoles"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 9
    func getPlayerSearchUserLeagues(success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetAllLeagues"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    //                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    }  else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 10
    func getPlayerSearchSelectPlayerProfile(playerId:Int, success:@escaping complitionArrSuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPlayerProfileMainInfo"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String : Any] {
                                success(result)
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    // 11
    func getPerformancePeriodsName (playerId:String, success:@escaping complitionObjSuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPlayerProfilePerformanceDataPeriods"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String] {
                                success(result)
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 12
    func getPerformancePeriodsData (playerId:String, period: String, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description, "period" : period] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPlayerProfilePerformanceData"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 13
    func getPlayerProfileCareerHistory (playerId:String, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPlayerProfileCareerHistory"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 14
    func getMyShortList (success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetMyShortList"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 15
    func deletePlayerFromMyShortList (playerId:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/DeletePlayerFromMyShortList"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 16
    func addPlayerToMyShortList (playerId:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/AddPlayerToMyShortList"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 17
    func declarePlayerInterest (playerId:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters = ["playerId": playerId.description] as [String : Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/Declareinterest"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 18
    func sendOfferBuy (playerId:String, currency:Curreency, transferFee:String, sellOn:String, description:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters: [String: Any] =  ["playerId": playerId,
                                          "currencyId": currency.currencyId,
                                          "currencyName": currency.currencyName,
                                          "transferFee": transferFee,
                                          "sellOn" : sellOn,
                                          "bonuses" : description]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/SendOfferBuy"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    // 19
    func getAllCurrencies (success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetAllCurrencies"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //20
    func sendOfferLoan (playerId:String, currency:Curreency, monthlyLoanFee:String, optionToBuy:Bool, startDate:String, endDate:String, description:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        let parameters: [String: Any] = [
            "playerId": playerId,
            "currencyId": currency.currencyId.description,
            "currencyName": currency.currencyName,
            "monthlyLoanFee": monthlyLoanFee.description,
            "optionToBuy" : optionToBuy,
            "startingDate" : startDate,
            "endingDate" : endDate,
            "description" : description
        ]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/SendOfferLoan"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            success()
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //24
    
    func getAllClubs(success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetAllClubs"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    //25
    
    func getUnreadMessageNumber(success:@escaping (Int) -> (), failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetUnreadMessages"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let countStr = response.result.value as? String, let countInt = Int(countStr) {
                                success(countInt)
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    //26
    
    func getCurrentUserInfo(success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        
        //        success()
        //        return
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetUserInfo"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [String : Any] {
                                CurrentUser.shared.aspId = result["AspId"] as? Int ?? 0
                                CurrentUser.shared.id = result["Id"] as? Int ?? 0
                                CurrentUser.shared.email = result["Email"] as? String ?? ""
                                CurrentUser.shared.fullName = result["FullName"] as? String ?? ""
                                CurrentUser.shared.userName = result["UserName"] as? String ?? ""
                                CurrentUser.shared.positionalRoleId = result["PositionalRoleId"] as? Int ?? 0
                                CurrentUser.shared.positionalRole = result["PositionalRole"] as? String ?? ""
                                CurrentUser.shared.currentCurrencyId = result["CurrentCurrencyId"] as? Int ?? 0
                                CurrentUser.shared.currentCurrencyName = result["CurrentCurrencyName"] as? String ?? ""
                                CurrentUser.shared.clubId = result["ClubId"] as? Int ?? 0
                                CurrentUser.shared.clubName = result["ClubName"] as? String ?? ""
                                CurrentUser.shared.clubApiId = result["ClubApiId"] as? Int ?? 0
                                CurrentUser.shared.cityId = result["CityId"] as? Int ?? 0
                                CurrentUser.shared.cityName = result["CityName"] as? String ?? ""
                                CurrentUser.shared.phone = result["Phone"] as? String ?? ""
                                CurrentUser.shared.createdAt = result["CreatedAt"] as? String ?? ""
                                CurrentUser.shared.updatedAt = result["UpdatedAt"] as? String ?? ""
                                CurrentUser.shared.active = result["Active"] as? Bool ?? false
                                CurrentUser.shared.userType = result["UserType"] as? Int ?? 0
                                CurrentUser.shared.approved = result["Approved"] as? Bool ?? false
                                CurrentUser.shared.lockCount = result["LockCount"] as? Int ?? 0
                                CurrentUser.shared.lockedTime = result["LockedTime"] as? String ?? ""
                                CurrentUser.shared.userTypeId = result["UserTypeId"] as? Int ?? 0
                                CurrentUser.shared.isFirstEntry = result["IsFirstEntry"] as? Bool ?? false
                                CurrentUser.shared.logoImage = result["LogoImage"] as? String ?? ""
                                CurrentUser.shared.logoImageFullPath = result["LogoImageFullPath"] as? String ?? ""
                                CurrentUser.shared.postCode = result["PostCode"] as? String ?? ""
                                CurrentUser.shared.address = result["Address"] as? String ?? ""
                                CurrentUser.shared.VATN = result["VATN"] as? String ?? ""
                                CurrentUser.shared.countryName = result["CountryName"] as? String ?? ""
                                CurrentUser.shared.countryId = result["CountryId"] as? Int ?? 0
                                CurrentUser.shared.clubNameRequest = result["ClubNameRequest"] as? String ?? ""
                                CurrentUser.shared.finishedRegistration = result["FinishedRegistration"] as? Int ?? 0
                                CurrentUser.shared.deleted = result["Deleted"] as? Bool ?? false
                                CurrentUser.shared.confirmEmail = result["ConfirmEmail"] as? Bool ?? false
                                CurrentUser.shared.clubActive = result["ClubActive"] as? Bool ?? false
                                success()
                            }  else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("Error get user detail.")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //27
    
    func getClubAdsSearch(_ keyWord: String, filter:ClubsFilter, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let parameters: [String: Any] = ["keyWord":keyWord as AnyObject,
                                         "positionsIds":filter.positionsIds.count > 0 ?
                                            ParseManager.parseArrayToString(filter.positionsIds) : "NULL",
                                         "leaguesIds":filter.leaguesIds.count > 0 ?
                                            ParseManager.parseSetToString(filter.leaguesIds) : "NULL",
                                         "clubsIds":filter.clubsIds,
                                         "nationalitiesIds":filter.nationalitiesIds,
                                         "transferTypeId":filter.transferTypeId! as Any,
                                         "contractExpiry":filter.contractExpiry,
                                         "isOrder":filter.isOrder as Any,
                                         "orderValue":filter.orderValue ?? "NULL",
                                         "orderType": filter.orderType as Any]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetClubAds"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                }
                            } else {
                                failed("\(response)")
                            }
                        case 401:
                            Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //28
    
    func createPlayerAd(firstPositionId:Int, transferTypeId:Int, monthlyLoanFee:Int, transferFee:Int, currencyIdLoan:Int, currencyIdSell:Int, optionToBuy:Bool, anonimClub:Bool, description:String, success:@escaping complitionEmptySuccess, failed:@escaping complitionFailed) {
        let parameters: [String: Any] =  [
            "description" : description,
            "firstPositionId" : firstPositionId,
            "secondPositionId" : 0,
            "transferTypeId" : transferTypeId,
            "monthlyLoanFee" : monthlyLoanFee,
            "transferFee"    : transferFee,
            "currencyIdLoan" : currencyIdLoan,
            "currencyIdSell" : currencyIdSell,
            "optionToBuy" : optionToBuy,
            "anonymousClub" : anonimClub
        ]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/CreatePlayerAdd"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate { request, response, data in
                    return .success
                } .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            print(response)
                            success()
                            //                    case 401:
                        //                        Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //29
    
    func getMessageBox(keyword:String?, status:Int, success:@escaping complitionDictSuccess, failed:@escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetMessageBox"
        
        let parameters: [String: Any] =  [
            "status" : status.description,
            "keyword" : keyword ?? ""
        ]
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers)
                .responseJSON { response in
                    if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                    if let status = response.response?.statusCode {
                        switch(status) {
                        case 200:
                            if let result = response.result.value as? [Any] {
                                if let data = result as? [[String : Any]] {
                                    success(data)
                                    return
                                }
                            } else {
                                failed("\(response)")
                            }
                            
                            //                    case 401:
                        //                        Utility.logoutUser()
                        default:
                            failed("\(response)")
                            print("error with response status: \(status)")
                        }
                    } else {
                        failed("\(response)")
                    }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //30
    
    func sendValidateAction(actionId: String, success: @escaping complitionEmptySuccess, failed: @escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let parameters: [String: Any] =  [
            "actionId" : actionId
        ]
        
        let endpoint: String = baseURLConnection + "api/Main/ValidateActionMobile"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        success()
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    //31
    
    func getAllClubsWithSearch(_ keyWord: String, success: @escaping complitionDictSuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = ["keyWord": keyWord as Any]
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetAllClubsWithSearch"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [Any] {
                            if let data = result as? [[String : Any]] {
                                success(data)
                                return
                            }
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }

        //32

    
    func pitchPlayerForLoan(playerId:Int, tranferBuyId:Int, loanFee:String, currencyName:String, positionId:Int, success: @escaping complitionEmptySuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = [
            "playerId" : playerId,
            "currentTransferBuyId" : tranferBuyId,
            "monthlyLoanFee" : loanFee,
            "monthlyLoanFee_CurrencyText" : currencyName,
            "position" : positionId
        ]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/PitchPlayerLoan"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        success()
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }

    //33
    
    
    func pitchPlayerForBuy (playerId:Int, tranferBuyId:Int, sellOn:String, signOnFee:String, monthlySalary: String, incomeTax: String, transferFrom:String, transferTo:String, currencyName:String, positionId:Int, success: @escaping complitionEmptySuccess, failed: @escaping complitionFailed) {
        
        var transferFeeFrom:Int = 0
        
        if let fee = Int(transferFrom) {
            transferFeeFrom = fee
        }
        
        let parameters: [String: Any] = [
            "playerId" : playerId,
            "currentTransferBuyId" : tranferBuyId,
            "sellOn" : sellOn,
            "signOnFee" : -1,
            "monthlySalary" : -1,
            "incomeTax" : -1,
            "transferFeeFrom" : transferFeeFrom,
            "transferFeeTo" : -1,
            "transferFeeFrom_CurrencyText" : currencyName,
            "position" : positionId
        ]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/PitchPlayerBuy"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        success()
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    
    //34
    
    func getAllPlayersForPitch(_ positionId: Int, success: @escaping complitionDictSuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = ["clubAdId": positionId as Any]
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetAllPlayersForPitch"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [Any] {
                            if let data = result as? [[String : Any]] {
                                success(data)
                                return
                            }
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    
    //35
    
    func addDeviceInfo(deviceId: String, failed: @escaping complitionFailed) {
        let parameters: [String: Any] = [
            "deviceType" : "iOS",
            "deviceId" : deviceId
        ]
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/AddDeviceInfo"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        print(response)
                    case 401:
                        Utility.logoutUser()
                    default:
                        print("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //36
    
    func getAllClubAdsForPlayerAds(success: @escaping complitionDictSuccess, failed: @escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetMyPlayerAds"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [Any] {
                            if let data = result as? [[String : Any]] {
                                success(data)
                                return
                            }
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                    
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    //37
    
    func getPitchedPlayerFor(clubAdId:Int, success: @escaping complitionDictSuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = ["clubAdId" : clubAdId.description]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/GetPitchesByClubAd"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [Any] {
                            if let data = result as? [[String : Any]] {
                                success(data)
                                return
                            }
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //38
    
    func removeClubAd(clubAdId:Int, success: @escaping complitionEmptySuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = ["clubAdId" : clubAdId.description]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/RemoveClubAd"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        success()
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
    }
    
    //39
    
    func matchMakerFor(playerID: String, success: @escaping complitionDictSuccess, failed: @escaping complitionFailed) {
        
        let parameters: [String: Any] = ["playerId" : playerID]
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endPoint: String = baseURLConnection + "api/Main/GetMatchMakerResults"
        
        if self.isNetworkReachability {
            manager.request(endPoint, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [Any] {
                            if let data = result as? [[String : Any]] {
                                success(data)
                                return
                            }
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
    
    //40
    
    func matchMakerPitchPlayers(playerId: String, transferBuyIds: [String], success: @escaping complitionEmptySuccess, failed: @escaping complitionFailed) {
        
        let transferAdsIds = (transferBuyIds.map{String($0)}).joined(separator: ",")
        let parameters: [String: Any] = ["playerId" : playerId.description,
                                         "transferBuyIds" : transferAdsIds]
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        let endpoint: String = baseURLConnection + "api/Main/PitchPlayersFromMatchMaker"
        if self.isNetworkReachability {
            manager.request(endpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        success()
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }

    }
    
    //41
    
    func getPitchMailInfo(mailId: String, success: @escaping complitionArrSuccess, failed: @escaping complitionFailed) {
        
        let headers:HTTPHeaders = ["Authorization":"\(AuthInfo.instance.tokenType!) \(AuthInfo.instance.accessToken!)"]
        
        let endpoint: String = baseURLConnection + "api/Main/GetPitchMailInfo?mailId=\(mailId)"
        
        if self.isNetworkReachability {
            manager.request(endpoint, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                if HTTP_DEBUG_MODE == 1 {print("Method: \(#function) \n Line: \(#line) \n response is \(response)")}
                if let status = response.response?.statusCode {
                    switch(status) {
                    case 200:
                        if let result = response.result.value as? [[String : Any]] {
                            success(result.first!)
                        } else {
                            failed("\(response)")
                        }
                    case 401:
                        Utility.logoutUser()
                    default:
                        failed("\(response)")
                        print("error with response status: \(status)")
                    }
                } else {
                    failed("\(response)")
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { failed("No Internet Available") }
        }
        
    }
}

