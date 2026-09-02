import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import Sortable from "sortablejs"

// Drag-and-drop ordering for a queue's conversation cards, backed by SortableJS.
export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  connect() {
    this.savedIds = this.conversationIds
    this.dragging = false
    this.missedRefresh = false
    this.blockMorphWhileDragging = (event) => {
      if (!this.dragging) return

      event.preventDefault()
      this.missedRefresh = true
    }
    this.listElement.addEventListener("turbo:before-morph-element", this.blockMorphWhileDragging)
    this.sortable = Sortable.create(this.listElement, {
      handle: "[data-queue-sort-handle]",
      filter: ".is-locked",
      preventOnFilter: false,
      draggable: "[data-conversation-id]",
      delay: 200,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      animation: 150,
      ghostClass: "is-drag-ghost",
      chosenClass: "is-dragging",
      onMove: (event) => !event.related?.classList.contains("is-locked"),
      onStart: () => { this.dragging = true },
      onEnd: () => {
        this.dragging = false
        this.save()
      }
    })
  }

  disconnect() {
    this.listElement.removeEventListener("turbo:before-morph-element", this.blockMorphWhileDragging)
    this.sortable?.destroy()
    this.sortable = null
    this.savedIds = null
  }

  async save() {
    const ids = this.conversationIds

    if (this.sameOrder(ids)) return this.catchUp()

    try {
      const response = await Turbo.fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          Accept: "application/json"
        },
        body: JSON.stringify({ conversation_ids: ids })
      })

      if (!response.ok) throw new Error(`Reorder failed with ${response.status}`)

      this.savedIds = ids
      this.catchUp()
    } catch (error) {
      console.error(error)
      window.location.reload()
    }
  }

  // Applies whatever was broadcast while the drag blocked morphing.
  catchUp() {
    if (!this.missedRefresh) return

    this.missedRefresh = false
    Turbo.visit(window.location.href, { action: "replace" })
  }

  get conversationIds() {
    return Array.from(
      this.listElement.querySelectorAll("[data-conversation-id]"),
      (card) => card.dataset.conversationId
    )
  }

  sameOrder(ids) {
    return this.savedIds?.length === ids.length && this.savedIds.every((id, index) => id === ids[index])
  }

  get listElement() {
    return this.hasListTarget ? this.listTarget : this.element
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
