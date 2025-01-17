//
//  SignView.swift
//  permasigneriOS
//
//  Created by 蕭博文 on 2022/7/5.
//

import SwiftUI
import UniformTypeIdentifiers
import AuxiliaryExecute
import ZipArchive

struct SignView: View {
    @StateObject var progress: Progress = .shared
    @StateObject var checkapp: CheckApp = .shared
    
    @State var isImporting: Bool = false
    @State var showAlert:Bool = false
    @State var alertTitle:String = ""
    @State var alertMeaasge:String = ""
    
    @State var showInFilzaAlert:Bool = false
    @State var canShowinFilza:Bool = false
    
    @State var ShowCustomInfo:Bool = false
    
    func signFailedAlert(title:String, message:String) {
        checkapp.fileName = ""
        alertTitle = title
        alertMeaasge = message
        showAlert.toggle()
    }
    
    var body: some View {
        VStack {
            Text(checkapp.fileName != "" ? "\(checkapp.fileName)" : "No ipa file selected")
            Button(action: {
                if isImporting {
                    isImporting = false
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.2, execute: {
                        isImporting = true
                    })
                } else {
                    isImporting = true
                }
            }, label: {Text("Select File")})
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMeaasge), dismissButton: .default(Text("OK")))
            }
            .disabled(progress.ProgressingDescribe != "")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType(filenameExtension: "ipa")!],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let fileUrl = try result.get()
                    checkapp.fileName = fileUrl.first!.lastPathComponent
                    checkapp.filePath = fileUrl.first!.path
                    
                    checkapp.extractIpa()
                    
                    if checkapp.checkIsIpaPayloadValid() {
                        checkapp.InfoPlistPath = checkapp.payloadPath.appendingPathComponent("\(checkapp.appNameInPayload)/Info.plist")
                        if checkapp.checkInfoPlist() {
                            checkapp.getInfoPlistValue()
                            if checkapp.validInfoPlist {
                                print("valid InfoPlist")
                            } else {
                                checkapp.app_executable = nil
                                signFailedAlert(title: "No executable found.", message: "Missing executable in Info.plist")
                            }
                        }
                    } else {
                        signFailedAlert(title: "IPA is not valid!", message: "The file might have missing parts\nor invalid contents")
                    }
                    isImporting = false
                } catch {
                    print(error.localizedDescription)
                }
            }
            .padding()
            
            Button(action: {
                ShowCustomInfo.toggle()
            }, label: {
                Text("Custom Info")
            }).sheet(isPresented: $ShowCustomInfo, content: {
                CustomInfoView()
            }).disabled(checkapp.fileName == "" || progress.ProgressingDescribe != "" || isImporting)
            
            Button(action: {
                DispatchQueue.global(qos: .userInitiated).async {
                    progress.permanentSignButtonFunc()
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        if progress.CheckDebBuild() {
                            if checkFilza() {
                                canShowinFilza = true
                            } else { canShowinFilza = false }
                            checkapp.fileName = ""
                            showInFilzaAlert.toggle()
                            
                        } else {
                            signFailedAlert(title: "Sign Failed", message: "Please try others iPA files")
                        }
                    }
                }
            }, label: {Text(progress.ProgressingDescribe == "" ? "Permanent sign" : progress.ProgressingDescribe)})
            .alert(isPresented: $showInFilzaAlert ){
                Alert(
                    title: Text(canShowinFilza ? "Done" : "Ohh no"),
                    message: Text(canShowinFilza ? "View the file now ?" : "You need Filza to view the file"),
                    primaryButton: .default(Text("Okay")) {
                        if canShowinFilza {
                            UIApplication.shared.open(URL(string: "filza://\(progress.OutputDebFilePath)")!)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .disabled(checkapp.fileName == "")
            .opacity(checkapp.fileName == "" ? 0.6 : 1.0)
            .buttonStyle(SignButtonStyle())
            
            if isImporting {
                ProgressView(label: {
                    Text("Importing iPA file")
                })
                .padding()
            }
        }
        .padding()
    }
}


struct CustomInfoView: View {
    @StateObject var checkapp: CheckApp = .shared
    @StateObject var progress: Progress = .shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack{
            VStack(alignment: .leading) {
                Text("Customize App Name")
                TextField("App Name", text: $checkapp.custom_app_name)
                    .textFieldStyle(.roundedBorder)
                Text("Customize App Bundle")
                TextField("App Bundle", text: $checkapp.custom_app_bundle)
                    .textFieldStyle(.roundedBorder)
                Text("Customize deb file description\n( Leave blank to use default )")
                TextField("Description", text: $progress.CustomDebDescription)
                    .textFieldStyle(.roundedBorder)
                Text("\nCustomized Name and Bundle are both required,\nif you want to prevent original apps being replaced\nRecommended to modify like this\n\nExampleApp2\ncom.example.exampleapp2")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }.padding()
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Done")
            }).padding()
        }
        .padding()
        .onTapGesture {
            hideKeyboard()
        }
    }
}


struct SignView_Previews: PreviewProvider {
    static var previews: some View {
        SignView()
        CustomInfoView()
    }
}

