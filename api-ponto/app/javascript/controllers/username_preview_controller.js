import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  update() {
    const nome = this.element.value
    if (!nome || nome.trim() === "") {
      this.previewTarget.value = ""
      return
    }

    const cleaned = nome
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-zA-Z\s]/g, "")
      .toLowerCase()
      .trim()
      .split(/\s+/)

    let username = ""
    if (cleaned.length >= 2) {
      username = cleaned[0] + "." + cleaned[cleaned.length - 1]
    } else if (cleaned.length === 1) {
      username = cleaned[0]
    }

    this.previewTarget.value = username || ""

    if (username) {
      this.previewTarget.disabled = false
      this.previewTarget.value = username
      this.previewTarget.disabled = true
    }
  }
}
