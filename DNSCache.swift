import Darwin
import Foundation

@Observable
final class DNSCache {
  private(set) var resolved: [String: String] = [:]
  private var pending: Set<String> = []
  private let queue = DispatchQueue(label: "dns-resolver", attributes: .concurrent)

  func resolve(_ ip: String) {
    if resolved[ip] != nil || pending.contains(ip) { return }
    pending.insert(ip)

    queue.async { [weak self] in
      var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let result: Int32

      if ip.contains(":") {
        var sa = sockaddr_in6()
        sa.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        sa.sin6_family = sa_family_t(AF_INET6)
        result =
          inet_pton(AF_INET6, ip, &sa.sin6_addr) == 1
          ? withUnsafePointer(to: &sa) { saPtr in
            saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
              getnameinfo(
                sockPtr, socklen_t(MemoryLayout<sockaddr_in6>.size),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NAMEREQD)
            }
          }
          : EAI_NONAME
      } else {
        var sa = sockaddr_in()
        sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        sa.sin_family = sa_family_t(AF_INET)
        result =
          inet_pton(AF_INET, ip, &sa.sin_addr) == 1
          ? withUnsafePointer(to: &sa) { saPtr in
            saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
              getnameinfo(
                sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NAMEREQD)
            }
          }
          : EAI_NONAME
      }

      let name: String?
      if result == 0 {
        let resolved = String(cString: hostname)
        name = (resolved != ip) ? resolved : nil
      } else {
        name = nil
      }

      DispatchQueue.main.async {
        self?.pending.remove(ip)
        if let name = name {
          self?.resolved[ip] = name
        } else {
          self?.resolved[ip] = ""
        }
      }
    }
  }

  func hostname(for ip: String) -> String? {
    if let name = resolved[ip], !name.isEmpty { return name }
    return nil
  }
}
