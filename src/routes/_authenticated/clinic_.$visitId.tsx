import { createFileRoute } from '@tanstack/react-router';
import { ConsultationPage } from '@/features/clinic/consultation/ConsultationPage';

export const Route = createFileRoute('/_authenticated/clinic_/$visitId')({
  component: ConsultationRouteComponent,
});

function ConsultationRouteComponent() {
  const { visitId } = Route.useParams();
  return <ConsultationPage visitId={visitId} />;
}
