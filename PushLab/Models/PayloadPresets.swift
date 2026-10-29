import Foundation

struct PayloadPreset: Identifiable, Hashable {
    let name: String
    let pushType: PushType
    let json: String
    var id: String { name }
}

enum PayloadPresets {
    static let defaultMessage = """
    {
       "aps" : {
          "alert" : {
             "title" : "PushLab",
             "subtitle" : "Test push notification",
             "body" : "Push payload body"
          }
       }
    }
    """

    static let all: [PayloadPreset] = [
        PayloadPreset(name: "Alert", pushType: .alert, json: defaultMessage),
        PayloadPreset(name: "Alert with badge and sound", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title" : "New message",
                 "body" : "You have a new message"
              },
              "badge" : 1,
              "sound" : "default"
           },
           "customKey" : "customValue"
        }
        """),
        PayloadPreset(name: "Localized alert", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title-loc-key" : "NOTIFICATION_TITLE",
                 "loc-key" : "NOTIFICATION_BODY",
                 "loc-args" : [ "Harsh", "3" ]
              },
              "sound" : "default"
           }
        }
        """),
        PayloadPreset(name: "Critical alert", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title" : "Critical alert",
                 "body" : "This bypasses Do Not Disturb"
              },
              "sound" : {
                 "critical" : 1,
                 "name" : "default",
                 "volume" : 1.0
              },
              "interruption-level" : "critical"
           }
        }
        """),
        PayloadPreset(name: "Time sensitive", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title" : "Time sensitive",
                 "body" : "Delivered even in Focus"
              },
              "interruption-level" : "time-sensitive",
              "relevance-score" : 1.0
           }
        }
        """),
        PayloadPreset(name: "Mutable content (service extension)", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title" : "Rich notification",
                 "body" : "Handled by a Notification Service Extension"
              },
              "mutable-content" : 1
           },
           "media-url" : "https://example.com/image.jpg"
        }
        """),
        PayloadPreset(name: "Thread / category", pushType: .alert, json: """
        {
           "aps" : {
              "alert" : {
                 "title" : "Grouped",
                 "body" : "Grouped by thread-id, actions from category"
              },
              "category" : "MESSAGE_CATEGORY",
              "thread-id" : "chat-42"
           }
        }
        """),
        PayloadPreset(name: "Badge only", pushType: .alert, json: """
        {
           "aps" : {
              "badge" : 5
           }
        }
        """),
        PayloadPreset(name: "Background (silent)", pushType: .background, json: """
        {
           "aps" : {
              "content-available" : 1
           },
           "syncReason" : "manual-test"
        }
        """),
        PayloadPreset(name: "Live Activity · start", pushType: .liveactivity, json: """
        {
           "aps" : {
              "timestamp" : \(Int(Date().timeIntervalSince1970)),
              "event" : "start",
              "content-state" : {
                 "status" : "started",
                 "progress" : 0.1
              },
              "attributes-type" : "MyActivityAttributes",
              "attributes" : {
                 "orderNumber" : "1234"
              },
              "alert" : {
                 "title" : "Order started",
                 "body" : "Your order is being prepared"
              }
           }
        }
        """),
        PayloadPreset(name: "Live Activity · update", pushType: .liveactivity, json: """
        {
           "aps" : {
              "timestamp" : \(Int(Date().timeIntervalSince1970)),
              "event" : "update",
              "content-state" : {
                 "status" : "on the way",
                 "progress" : 0.7
              }
           }
        }
        """),
        PayloadPreset(name: "Live Activity · end", pushType: .liveactivity, json: """
        {
           "aps" : {
              "timestamp" : \(Int(Date().timeIntervalSince1970)),
              "event" : "end",
              "dismissal-date" : \(Int(Date().timeIntervalSince1970) + 600),
              "content-state" : {
                 "status" : "delivered",
                 "progress" : 1.0
              }
           }
        }
        """),
        PayloadPreset(name: "VoIP", pushType: .voip, json: """
        {
           "callerName" : "PushLab",
           "callId" : "4A1F8E2C",
           "handle" : "+10000000000"
        }
        """),
        PayloadPreset(name: "Complication", pushType: .complication, json: """
        {
           "aps" : {
              "content-available" : 1
           },
           "complication" : "refresh"
        }
        """),
        PayloadPreset(name: "MDM", pushType: .mdm, json: """
        {
           "mdm" : "PUSH_MAGIC_TOKEN"
        }
        """)
    ]
}
