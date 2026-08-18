import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/clinic/$visitId")({
  component: ClinicVisitTestPage,
});

function ClinicVisitTestPage() {
  const { visitId } = Route.useParams();

  return (
    <div className="min-h-screen p-8">
      <div className="rounded-lg border bg-card p-6 shadow-sm">
        <h1 className="text-2xl font-bold">
          VISIT PAGE WORKING
        </h1>

        <p className="mt-4 text-muted-foreground">
          Visit ID:
        </p>

        <p className="mt-1 font-mono text-sm">
          {visitId}
        </p>
      </div>
    </div>
  );
}