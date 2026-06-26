import type { ReactNode } from 'react'
import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import type { DragEndEvent } from '@dnd-kit/core'
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

export type DragHandleProps = Record<string, any>

// Generic vertical drag-to-reorder list. `renderItem` receives the item plus
// props to spread onto whatever element should act as the drag handle.
export function SortableList<T extends { id: string }>(props: {
  items: T[]
  onReorder: (next: T[]) => void
  renderItem: (item: T, handle: DragHandleProps) => ReactNode
}) {
  const { items, onReorder, renderItem } = props
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (over && active.id !== over.id) {
      const oldIndex = items.findIndex((i) => i.id === active.id)
      const newIndex = items.findIndex((i) => i.id === over.id)
      if (oldIndex >= 0 && newIndex >= 0) onReorder(arrayMove(items, oldIndex, newIndex))
    }
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={items.map((i) => i.id)} strategy={verticalListSortingStrategy}>
        {items.map((item) => (
          <SortableRow key={item.id} id={item.id}>
            {(handle) => renderItem(item, handle)}
          </SortableRow>
        ))}
      </SortableContext>
    </DndContext>
  )
}

function SortableRow({
  id,
  children,
}: {
  id: string
  children: (handle: DragHandleProps) => ReactNode
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id })
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.6 : 1,
  }
  return (
    <div ref={setNodeRef} style={style}>
      {children({ ...attributes, ...listeners })}
    </div>
  )
}
