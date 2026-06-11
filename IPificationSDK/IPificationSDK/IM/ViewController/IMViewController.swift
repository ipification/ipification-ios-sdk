//
//  IMViewController.swift
//  IPificationSDK
//
//  Created by Mac on 22.11.2021.
//

import UIKit

class IMViewController: UIViewController {
    /// The stack view that contains the available provider buttons.
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
    /// The label that displays the authentication instructions.
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
        
        descriptionTextView.text = imLocale.desc
        descriptionTextView.textColor = imTheme.descColor
        
        mainView.backgroundColor = imTheme.backgroundColor
        
        imStackView.spacing = 20
        
        if(imSession != nil && imSession!.availableProviders().count > 0){
            for provider in imSession!.availableProviders(){
      
                switch(provider.brand){
                    case "whatsapp", "wa":
                        let whatsappBtn = LeftAlignedButton()
                        whatsappBtn.backgroundColor = UIColor(hexString: "#25d366")
                        let waimage  = UIImage(named: "whatsapp", in: myProjectBundle, compatibleWith: nil)
                        whatsappBtn.setTitle(imLocale.whatsappBtnText, for: .normal)
                        whatsappBtn.setImage(waimage, for: .normal)
                        if(provider.installed == true || IPConfiguration.sharedInstance.validateIMApps == false){
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
                        if(provider.installed == true || IPConfiguration.sharedInstance.validateIMApps == false){
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
                        if(provider.installed == true || IPConfiguration.sharedInstance.validateIMApps == false){
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
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            self.delayToCheckSessionComplete()
        }
//        setupView()
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
//                    print("aaaa")
                    
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
    
    func createSpinnerView() {
        let child = SpinnerViewController()

        // add the spinner view controller
        addChild(child)
        child.view.frame = view.frame
        view.addSubview(child.view)
        child.didMove(toParent: self)

        // wait two seconds to simulate some work happening
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // then remove the spinner view controller
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    @IBAction func onDone(_ sender: Any) {
        self.callbackCanceled?()
        dismiss(animated: true)
    }
    @IBAction func onClick(_ sender: UIButton) {
        createSpinnerView()
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

       // wait two seconds to simulate some work happening
       DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
           // then remove the spinner view controller
           self.child?.willMove(toParent: nil)
           self.child?.view.removeFromSuperview()
           self.child?.removeFromParent()
       }
   }
   func hideLoadingView(){
       child?.willMove(toParent: nil)
       child?.view.removeFromSuperview()
       child?.removeFromParent()
   }
   
    //
//    private func setupView(){
//
//    }
//
//    @objc func didTapResetBtn(_ tapGR: UITapGestureRecognizer) {
//        if let text = tfTime.text{
//            counter = Int(text) ?? 60
//        }
//        timerStop?.invalidate()
//        timerLabel.text = "\(self.counter)"
//    }
//
//    @objc func didTapStopBtn(_ tapGR: UITapGestureRecognizer) {
//        timerStop?.invalidate()
//    }
//
//    @objc func didTapPlayBtn(_ tapGR: UITapGestureRecognizer) {
//        if let text = tfTime.text{
//            counter = Int(text) ?? 60
//        }
//
//        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
//            self.counter -= 1
//            self.timerLabel.text = "\(self.counter)"
//            self.timerStop = timer
//            if self.counter == 0 {
//                timer.invalidate()
//            }
//        }
//    }
}

extension IMViewController{
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
}
