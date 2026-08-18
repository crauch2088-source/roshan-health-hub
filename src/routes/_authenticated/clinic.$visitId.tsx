import { createFileRoute, useParams } from "@tanstack/react-router";

export const Route = createFileRoute(
  "/_authenticated/clinic/$visitId"
)({
  component: TestPage,
});

function TestPage() {
  const { visitId } = useParams({
    from: "/_authenticated/clinic/$visitId",
  });

  return (
    <div style={{ padding: 40 }}>
      <h1>VISIT PAGE WORKING</h1>
      <p>Visit ID: {visitId}</p>
    </div>
  );
}