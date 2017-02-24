Pod::Spec.new do |s|

  s.name         = "ZFScreenRecorder"
  s.version      = "0.0.1"
  s.summary      = "性能很好的录屏，支持GPUImage的所有操作。"

  s.description  = <<-DESC
                   录屏

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.homepage     = "https://github.com/zhfeng20108/ZFScreenRecorder"

  s.license      = "MIT"

  s.author             = { "zhfeng" => "hhzhangfeng2008@163.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/zhfeng20108/ZFScreenRecorder.git", :tag => "0.0.1" }

  s.source_files  = "ZFScreenRecorder/*.{h,m}"

  s.requires_arc = true

  s.dependency "GPUImage"

end
