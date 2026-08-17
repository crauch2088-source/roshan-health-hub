import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/patients')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/_authenticated/patients"!</div>
}
