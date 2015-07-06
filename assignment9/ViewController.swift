//
//  ViewController.swift
//  assignment9
//  http://stackoverflow.com/questions/25370442
//  Created by System Administrator on 27/05/2015.
//  Copyright (c) 2015 System Administrator. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var startPauseBtn: UIButton!
    
    var downloadOperation: AFDownloadRequestOperation?
    var tempFile: String?
    
    
    var networkMonitor: AFNetworkReachabilityManager?
    var retrying = true
    
    let url = NSURLRequest(
                    URL: NSURL(string: "http://cloudfront.stitcher.com/38267026.mp3")!,
            cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData,
        timeoutInterval: 1
    )
    
    lazy var saveTo: String = {
        let paths = NSSearchPathForDirectoriesInDomains(
            NSSearchPathDirectory.DocumentDirectory,
            NSSearchPathDomainMask.UserDomainMask, true);
        let fileName = paths[0] as! String;
        return fileName.stringByAppendingPathComponent(self.url.URL!.lastPathComponent!)
    }()
    
    let pauseLabel = "Pause"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resume()
    }
    
    @IBAction private func onClick(sender: AnyObject) {
        if retrying {
            stopMonitoring()
            startPauseBtn.setTitle("Retry", forState: .Normal)
            progressLabel.text = "Download incompleted"
        } else if startPauseBtn.titleLabel!.text == pauseLabel {
            pause()
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    func stopMonitoring() {
        networkMonitor?.stopMonitoring()
        retrying = false
    }
    
    func pause() -> Bool {
        if let downloader = downloadOperation {
            startPauseBtn.setTitle("Resume", forState: .Normal)
            downloader.pause()
            downloadOperation = nil
            return true
        }
        return false
    }
    
    private func onFail() {
        self.retrying = true
        self.pause()
        self.startPauseBtn.setTitle("Stop", forState: .Normal)
        self.progressLabel.text = "Host unreachable, retrying.."
    }
    
    func startMonitoring() {
        self.retrying = true
        networkMonitor = AFNetworkReachabilityManager(forDomain: self.url.URL!.host)
        networkMonitor!.startMonitoring()
        networkMonitor!.setReachabilityStatusChangeBlock({(status: AFNetworkReachabilityStatus) in
            if status == AFNetworkReachabilityStatus.NotReachable {
                self.onFail()
            } else if self.retrying {
                self.resume()
            }
            println("watching")
        })
    }
    
    private func resume() {
        retrying = false
        startPauseBtn.enabled = false
        startPauseBtn.setTitle(pauseLabel, forState: .Normal)
        startPauseBtn.setTitle("connecting..", forState: .Disabled)
        if tempFile != nil {
            println("Resuming..")
            downloadOperation = AFDownloadRequestOperation(
                request: url,
                fileIdentifier: tempFile?.lastPathComponent,
                targetPath: saveTo,
                shouldResume: true
            )
        } else {
            NSFileManager().removeItemAtPath(saveTo, error: nil)
            
            downloadOperation = AFDownloadRequestOperation(
                request: url,
                targetPath: saveTo,
                shouldResume: false
            )
        }
        
        if let downloader = downloadOperation {
            downloader.setDownloadProgressBlock({_, loaded, total in
                self.startPauseBtn.enabled = true
                let downloaded = loaded + downloader.offsetContentLength
                var progress = Float(downloaded) / Float(total + downloader.offsetContentLength)
                let mb = String(format: "%.2f", Float(downloaded/1024)/1024)
                self.progressBar.setProgress(progress, animated: true)
                progress *= 100
                self.progressLabel.text = "\(mb) Mb loaded (\(Int(progress))%)"
            })
            
            downloader.setCompletionBlockWithSuccess({_,_ in
                    self.tempFile = nil
                    self.startPauseBtn.setTitle("Redownload", forState: .Normal)
                    self.stopMonitoring()
                    self.downloadOperation = nil
                }, failure: {_,_ in
                    self.startPauseBtn.enabled = true
                    self.onFail()
                }
            )
            tempFile = downloader.tempPath()
            downloader.start()
        }
    }
}