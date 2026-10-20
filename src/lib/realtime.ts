import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";

import { supabase } from "./supabase";

/** Branch-scoped subscriptions plus a quiet polling fallback; RLS remains the security boundary. */
export function useBranchRealtime(branchId: string | null | undefined, orderId?: string): void {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!branchId) return;

    let disposed = false;
    const timers = new Map<string, ReturnType<typeof setInterval>>();
    const channels: ReturnType<typeof supabase.channel>[] = [];

    const invalidate = (table: "queue_tickets" | "lab_orders" | "visits") => {
      if (disposed) return;
      if (table === "queue_tickets") {
        void queryClient.invalidateQueries({ queryKey: ["queue-tickets"] });
        void queryClient.invalidateQueries({ queryKey: ["queue"] });
      } else if (table === "lab_orders") {
        void queryClient.invalidateQueries({ queryKey: ["lab-orders"] });
        if (orderId) {
          void queryClient.invalidateQueries({ queryKey: ["lab-order", orderId] });
          void queryClient.invalidateQueries({ queryKey: ["lab-items", orderId] });
          void queryClient.invalidateQueries({ queryKey: ["lab-order-results", orderId] });
        }
      } else {
        void queryClient.invalidateQueries({ queryKey: ["visits"] });
        void queryClient.invalidateQueries({ queryKey: ["visit"] });
      }
    };

    const subscribe = (
      topic: "queue" | "lab" | "visits",
      table: "queue_tickets" | "lab_orders" | "visits",
    ) => {
      const key = topic + ":" + branchId;
      const fallback = () => {
        if (disposed || timers.has(key)) return;
        timers.set(
          key,
          setInterval(() => invalidate(table), 45_000),
        );
      };

      const channel = supabase
        .channel("branch:" + branchId + ":" + topic, { config: { private: true } })
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table,
            filter: "branch_id=eq." + branchId,
          },
          () => invalidate(table),
        )
        .subscribe((status) => {
          if (status === "SUBSCRIBED") {
            const timer = timers.get(key);
            if (timer) clearInterval(timer);
            timers.delete(key);
          } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
            fallback();
          }
        });

      channels.push(channel);
      fallback();
    };

    subscribe("queue", "queue_tickets");
    subscribe("lab", "lab_orders");
    subscribe("visits", "visits");

    return () => {
      disposed = true;
      for (const timer of timers.values()) clearInterval(timer);
      timers.clear();
      for (const channel of channels) void supabase.removeChannel(channel);
    };
  }, [branchId, orderId, queryClient]);
}
