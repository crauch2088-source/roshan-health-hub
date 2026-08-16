import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";

import { AppShell } from "@/components/app-shell";
import { Loading } from "@/components/kit";
import { useAuth } from "@/lib/auth";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated")({
  ssr: false,
    beforeLoad: async () => {
        const { data, error } = await supabase.auth.getUser();
            if (error || !data.user) throw redirect({ to: "/auth" });
                return { authUser: data.user };
                  },
                    component: ProtectedLayout,
                    });

                    function ProtectedLayout() {
                      const { loading } = useAuth();

                        if (loading) {
                            return (
                                  <div className="flex min-h-screen items-center justify-center">
                                          <Loading />
                                                </div>
                                                    );
                                                      }

                                                        return (
                                                            <AppShell>
                                                                  <Outlet />
                                                                      </AppShell>
                                                                        );
                                                                        }
                                                                        