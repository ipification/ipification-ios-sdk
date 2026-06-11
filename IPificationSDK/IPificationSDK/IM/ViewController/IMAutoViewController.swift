//
//  IMAutoViewController.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 25/05/2023.
//  Copyright © 2023 IPification Dev Team. All rights reserved.
//

import UIKit

class IMAutoViewController: UIViewController {
    /// The stack view that contains automatic-mode status content.
    @IBOutlet weak var imStackView: UIStackView!
    /// The root content view styled by the configured theme.
    @IBOutlet weak var mainView: UIView!
    /// The notification observer used to resume the IM flow after returning to the app.
    private var observer: NSObjectProtocol?
    /// The IM session displayed by this controller.
    var imSession: IMSession?
    
    /// Called when IM authentication succeeds.
    var callbackSuccess: ((_ response: AuthorizationResponse) -> Void)?
    /// Called when IM authentication fails.
    var callbackFailed: ((_ response: IPificationException) -> Void)?
    /// Called when the user cancels authentication.
    var callbackCanceled: (() -> Void)?
    /// Called with IM diagnostic messages.
    var callbackLog: ((_ response: String) -> Void)?
    /// The localized text displayed by this controller.
    var imLocale : IPificationLocale = IPificationLocale.sharedInstance
    /// The colors applied by this controller.
    var imTheme : IPificationTheme = IPificationTheme.sharedInstance
    /// The available WhatsApp provider configuration.
    var waInfo: ProviderInfo?
    /// The available Telegram provider configuration.
    var telegramInfo: ProviderInfo?
    /// The available Viber provider configuration.
    var viberInfo: ProviderInfo?
    //    public var tfTime: UITextField!
    //    public var timerLabel: UILabel!
    //
    //    var counter = 60
    //    var timerStop: Timer?
    //
    /// The label that displays the screen title.
    @IBOutlet weak var titleTextView: UILabel!
    /// The label that displays automatic-mode status text.
    @IBOutlet weak var descriptionTextView: UILabel!
    /// The SDK resource bundle used to load provider images.
    let myProjectBundle = Bundle(identifier: "bvl.IPificationSDK")!
    //
    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        super.viewDidLoad()
        navigationItem.title = imLocale.topTitle
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: imLocale.cancelBtnText, style: .plain, target: self, action: #selector(onDone))
        
        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.standardAppearance.titleTextAttributes = [.foregroundColor: imTheme.toolbarTitleColor]
        } else {
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: imTheme.toolbarTitleColor]
        }
        
        navigationItem.rightBarButtonItem?.tintColor = imTheme.cancelBtnColor
        
        titleTextView.text = imLocale.title
        titleTextView.textColor = imTheme.titleColor
        
        descriptionTextView.textColor = imTheme.descColor
        mainView.backgroundColor = imTheme.backgroundColor
        
        
        startCheckingSession()
        
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            self.delayToCheckSessionComplete()
        }
        showAutoHideLoadingView()
    }
    func startCheckingSession(){
        let app = imSession?.findFirstInstalledApp(supportedProviders: imSession?.availableProviders())
        if(app != nil){
            DispatchQueue.main.async {
                self.descriptionTextView.text = String(format: self.imLocale.autoDesc, app?.getBrand().capitalized ?? "")
            }
            let link = app?.message
            guard let imLink = link else {
                return
            }
            IMNetwork.sharedInstance.getRedirectLink(url: imLink, completion: {(response, error) in
                if(error != nil || response == nil){
                    self.openLink(link: imLink)
                    return
                }
                self.openLink(link: response ?? imLink)
            })
            
        }else{
            
        }
    }
    func delayToCheckSessionComplete(){
        DispatchQueue.main.async {
            self.showLoadingView()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.checkSessionComplete()
        }
    }
    func checkSessionComplete(){
        
//        DispatchQueue.main.async {
//            self.showLoadingView()
//        }
        onLogs( "[IM Screen] check session complete with session id: \(imSession?.sessionID ?? "")")
        IMNetwork.sharedInstance.completeSession(imSession: imSession!, completion: {(response, error) in
            DispatchQueue.main.async {
                self.hideLoadingView()
            }
            if(error != nil){
                //                print("error_message", error?.localizedDescription , error!.message, response?.getPlainResponse())
                self.onLogs( "[IM Screen] error \(error!.message) \(response?.getPlainResponse() ?? "") ")
                
                if(error?.message == "pending"){
                    DispatchQueue.main.async{
                        self.setLayout()
                    }
                    return
                }
                if(error?.message == "not_found"){
                    
                    self.showAlert(IPificationLocale.sharedInstance.errorMsgSessionNotFound){ () -> () in
                        self.callbackFailed?(IPificationException(IPificationError.authorized_failed, error?.message ?? "unknown error"))
                        DispatchQueue.main.async{
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                    return
                    
                }
                if(error?.message == "finished"){
                    if(IPConfiguration.sharedInstance.IM_AUTO_MODE){
                        let response  = AuthorizationResponse(res: "\(IPConfiguration.sharedInstance.REDIRECT_URI)?state=\(IPConfiguration.sharedInstance.currentState)&code=no-auth_code-for-automode")
                        self.callbackSuccess?(response)
                        DispatchQueue.main.async{
                            self.dismiss(animated: true, completion: nil)
                        }
                        return
                    }
                    
                    self.showAlert(IPificationLocale.sharedInstance.errorMsgSessionAlreadyCompleted){ () -> () in
                        self.callbackFailed?(IPificationException(IPificationError.authorized_failed, error?.message ?? "unknown error"))
                        DispatchQueue.main.async{
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                    return
                }
                DispatchQueue.main.async{
                    self.callbackFailed?(IPificationException(IPificationError.authorized_failed, error?.message ?? error?.localizedDescription ??
                                                              response?.getPlainResponse() ?? "unknown error"))
                    self.dismiss(animated: true, completion: nil)
                }
                return
            }
            if let response = response, let code = response.getCode(){
                //                print("getCode",response!.getCode()!)
                self.onLogs( "[IM Screen] completed success with code: \(code)")
                self.callbackSuccess?(response)
                DispatchQueue.main.async{
                    self.dismiss(animated: true, completion: nil)
                }
                
            }else if(response != nil){
                self.onLogs( "[IM Screen] error: \(response!.getPlainResponse())")
                print("error", response!.getPlainResponse())
                self.callbackFailed?(IPificationException(IPificationError.authorized_failed, response!.getPlainResponse()))
            }else{
                self.callbackFailed?(IPificationException(IPificationError.authorized_failed, "unknown error"))
            }
            
        })
        //        self.callbackSuccess?(nil)
        //        DispatchQueue.main.async {
        //            self.hideLoadingView()
        //        }
        //        DispatchQueue.main.async{
        //            self.dismiss(animated: true, completion: nil)
        //        }
    }
    
    
    
    //
    
    func openLink(link: String){
        onLogs( "[IM Screen] Open redirected link: \(link)")
        DispatchQueue.main.async{
            guard let url = URL(string: link) else {
                self.onLogs("[IM Screen] Invalid redirected link: \(link)")
                return
            }
            UIApplication.shared.open(url)
        }
    }
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    
    /// The loading overlay currently presented by the controller.
    private var child : SpinnerViewController? = nil
    func showLoadingView() {
        child = SpinnerViewController()
        
        // add the spinner view controller
        guard let child = child else {
            return
        }
        addChild(child)
        child.view.frame = view.frame
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }
    func showAutoHideLoadingView() {
        let spinner = SpinnerViewController()
        
        // add the spinner view controller
        addChild(spinner)
        spinner.view.frame = view.frame
        view.addSubview(spinner.view)
        spinner.didMove(toParent: self)
        
        // wait two seconds to simulate some work happening
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // then remove the spinner view controller
            spinner.willMove(toParent: nil)
            spinner.view.removeFromSuperview()
            spinner.removeFromParent()
        }
    }
    func hideLoadingView(){
        child?.willMove(toParent: nil)
        child?.view.removeFromSuperview()
        child?.removeFromParent()
    }
    
    
    func setLayout(){
        imStackView.subviews.forEach { $0.removeFromSuperview() }

        imStackView.spacing = 20
        descriptionTextView.text = imLocale.desc
        if(imSession != nil && imSession!.availableProviders().count > 0){
            let provider = imSession?.findFirstInstalledApp(supportedProviders: imSession?.availableProviders())

            switch(provider?.brand){
                case "whatsapp", "wa":
                    let whatsappBtn = LeftAlignedButton()
                    whatsappBtn.backgroundColor = UIColor(hexString: "#25d366")
                    let waimage  = UIImage(named: "whatsapp", in: myProjectBundle, compatibleWith: nil)
                    whatsappBtn.setTitle(imLocale.whatsappBtnText, for: .normal)
                    whatsappBtn.setImage(waimage, for: .normal)
                    if(provider?.installed == true){
                            waInfo = provider
                            whatsappBtn.tag = 1
                            whatsappBtn.addTarget(self, action: #selector(onClick), for: .touchUpInside)
                            whatsappBtn.alpha = 1
                    }else {
                        whatsappBtn.alpha = 0.3
                    }
                    
                    imStackView.addArrangedSubview(whatsappBtn)
                    break
                case "telegram":
                    let telegramBtn = LeftAlignedButton()
                    telegramBtn.backgroundColor = UIColor(hexString: "#0088cc")
                    let telegramImage  = UIImage(named: "telegram", in: myProjectBundle, compatibleWith: nil)
                    telegramBtn.setTitle(imLocale.telegramBtnText, for: .normal)
                    telegramBtn.setImage(telegramImage, for: .normal)
                    if(provider?.installed == true){
                        telegramInfo = provider
                        telegramBtn.tag = 2
                        telegramBtn.addTarget(self, action: #selector(onClick), for: .touchUpInside)
                        telegramBtn.alpha = 1
                    }else {
                        telegramBtn.alpha = 0.3
                    }
                
                    imStackView.addArrangedSubview(telegramBtn)
                    break
                case "viber":
                    let viberBtn = LeftAlignedButton()
                    viberBtn.backgroundColor = UIColor(hexString: "#665CAC")
                    let viberImage  = UIImage(named: "viber", in: myProjectBundle, compatibleWith: nil)
                    viberBtn.setTitle(imLocale.viberBtnText, for: .normal)
                    viberBtn.setImage(viberImage, for: .normal)
                    if(provider?.installed == true){
                        viberInfo = provider
                        viberBtn.tag = 3
                        viberBtn.addTarget(self, action: #selector(onClick), for: .touchUpInside)
                        viberBtn.alpha = 1
                    }else {
                        viberBtn.alpha = 0.3
                    }
                    imStackView.addArrangedSubview(viberBtn)
                    break
                default:
                    break
            }
        }
    }
    @IBAction func onClick(_ sender: UIButton) {
        showAutoHideLoadingView()
        var link : String?
        switch(sender.tag){
            case 1:
                link = waInfo?.message
                break
            case 2:
                link = telegramInfo?.message
                break
            case 3:
                link = viberInfo?.message
                break
            default:
                break
        }
        
        
        if let imLink = link{
            onLogs( "[IM Screen] IM link: \(imLink)")
            IMNetwork.sharedInstance.getRedirectLink(url: imLink, completion: {(response, error) in
                if(error != nil || response == nil){
                    self.openLink(link: imLink)
                    return
                }
                self.openLink(link: response ?? imLink)
            })

        }
    }
    
}

extension IMAutoViewController{
    func showAlert(_ message: String, completion: @escaping ()->()){
        
        DispatchQueue.main.async
        {
            let dialogMessage = UIAlertController(title: IPificationLocale.sharedInstance.imErrorTitleText, message: message, preferredStyle: .alert)
            dialogMessage.addAction(UIAlertAction(title: IPificationLocale.sharedInstance.imErrorButtonText, style: UIAlertAction.Style.default, handler: { _ in
                completion()
            }))
            // Present alert to user
            self.present(dialogMessage, animated: true, completion: nil)
        }
        
    }
    
    func onLogs(_ log: String) {
        if(IPConfiguration.sharedInstance.debug){
            IPLogs.sharedInstance.append(log)
        }
    }
    
    @IBAction func onDone(_ sender: Any) {
        self.callbackCanceled?()
        dismiss(animated: true)
    }
}
