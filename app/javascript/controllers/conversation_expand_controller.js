import { Controller } from "@hotwired/stimulus"

// Expand/collapse a conversation card's answers, persists it's state across any update broadcasts.
const openIds = new Set()

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.reapply = () => this.apply()
    document.addEventListener("turbo:morph", this.reapply)
    this.apply()
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reapply)
  }

  toggle() {
    if (openIds.has(this.conversationId)) {
      openIds.delete(this.conversationId)
    } else {
      openIds.add(this.conversationId)
    }

    this.apply()
  }

  apply() {
    this.contentTarget.classList.toggle("is-expanded", openIds.has(this.conversationId))
  }

  // The card already carries its id for drag-and-drop; no need to repeat it.
  get conversationId() {
    return this.element.dataset.conversationId
  }
}
