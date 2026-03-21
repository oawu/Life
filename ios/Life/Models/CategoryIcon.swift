import Foundation

enum CategoryIcon {
  struct Group {
    let name: String
    let icons: [String]
  }

  static let groups: [Group] = [
    Group(name: "餐飲", icons: [
      "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
      "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill",
      "carrot.fill", "fish.fill",
    ]),
    Group(name: "交通", icons: [
      "car.fill", "bus.fill", "tram.fill", "bicycle",
      "airplane", "fuelpump.fill", "p.square.fill",
      "ferry.fill", "scooter",
    ]),
    Group(name: "購物", icons: [
      "bag.fill", "cart.fill", "basket.fill", "tshirt.fill",
      "shoe.fill", "eyeglasses", "gift.fill", "tag.fill",
    ]),
    Group(name: "居住", icons: [
      "house.fill", "building.2.fill", "bed.double.fill", "sofa.fill",
      "lamp.desk.fill", "washer.fill", "key.fill", "lightbulb.fill",
    ]),
    Group(name: "娛樂", icons: [
      "gamecontroller.fill", "film.fill", "music.note", "tv.fill",
      "headphones", "book.fill", "theatermasks.fill", "camera.fill",
      "paintpalette.fill",
    ]),
    Group(name: "財務", icons: [
      "creditcard.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
      "arrow.left.arrow.right", "percent", "building.columns.fill",
    ]),
    Group(name: "健康", icons: [
      "cross.case.fill", "heart.fill", "pills.fill", "figure.run",
      "dumbbell.fill", "stethoscope", "brain.head.profile",
    ]),
    Group(name: "通訊", icons: [
      "phone.fill", "envelope.fill", "wifi", "antenna.radiowaves.left.and.right",
      "simcard.fill", "globe",
    ]),
    Group(name: "其他", icons: [
      "star.fill", "bookmark.fill", "paperclip", "wrench.fill",
      "scissors", "pencil", "doc.fill", "folder.fill",
      "desktopcomputer", "repeat", "questionmark.circle.fill",
      "sunrise.fill", "sun.max.fill", "moon.fill",
    ]),
  ]

  static let all: [String] = groups.flatMap(\.icons)
}
