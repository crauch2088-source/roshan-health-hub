import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2, Receipt } from "lucide-react";
import { buttonVariants, Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Loading, StatusBadge } from "@/components/kit";
import { useAuth } from "@/lib/auth";
import { n, rel, rpc, s, useRows, useSave, useSettings, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge, money } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { ClinicalNoteTab } from "./components/ClinicalNoteTab";
import { VitalsTab } from "./components/VitalsTab";
import { LaboratoryTab } from "./components/LaboratoryTab";
import { PrescriptionTab } from "./components/PrescriptionTab";
import { HistoryTab } from "./components/HistoryTab";

export function ConsultationPage({visitId}:{visitId:string}){
 const {lang}=useLang();const {user}=useAuth();const {currency}=useSettings();const [tab,setTab]=useState("note");
 const visitQ=useRows<Row[]>(["consultation-visit",visitId],()=>supabase.from("visits").select("id,visit_number,status,visit_date,patient_id,doctor_id,department_id,consultation_fee,patients(id,full_name,mrn,gender,date_of_birth),departments(name,name_ar),users!visits_doctor_id_fkey(full_name)").eq("id",visitId).limit(1));
 const visit=(visitQ.data??[])[0] as Row|undefined;const patient=rel(visit,"patients");
 const finish=useSave(async()=>{const {error}=await supabase.from("visits").update({status:"completed",completed_at:new Date().toISOString(),updated_by:user?.id??null}).eq("id",visitId);if(error)throw new Error(error.message);return null;},{invalidate:[["consultation-visit",visitId],["clinic-visits"],["visits"]],successMessage:"تم إنهاء الزيارة"});

 // Visit -> Billing integration. visits.tsx already auto-creates an invoice
 // (linked via invoices.visit_id) at the moment the visit is created, IF a
 // consultation fee was set then. This just surfaces that link here, and —
 // only if no invoice exists yet for this visit_id — offers a safe way to
 // create one, using the exact same insert shape visits.tsx uses. Checking
 // for an existing row first is what prevents a duplicate invoice.
 const invoiceQ=useRows<Row[]>(["consultation-invoice",visitId],()=>supabase.from("invoices").select("id,invoice_number,net_amount,paid_amount,status").eq("visit_id",visitId).is("deleted_at",null).limit(1),{enabled:Boolean(visitId)});
 const existingInvoice=(invoiceQ.data??[])[0] as Row|undefined;

 const createInvoice=useSave(async()=>{
   if(!visit) throw new Error("Visit not loaded");
   const fee=n(visit,"consultation_fee");
   if(fee<=0) throw new Error(lang==="ar"?"رسوم الاستشارة غير محددة أو صفر":"Consultation fee is not set or is zero");
   const invoiceNumber=await rpc<string>("next_invoice_number");
   const {data:inv,error}=await supabase.from("invoices").insert({
     invoice_number:invoiceNumber,
     patient_id:s(visit,"patient_id"),
     visit_id:visitId,
     invoice_date:new Date().toISOString().slice(0,10),
     total_amount:fee,
     subtotal:fee,
     discount_amount:0,
     net_amount:fee,
     paid_amount:0,
     status:"unpaid",
     payment_status:"unpaid",
     created_by:user?.id??null,
   }).select("id").single();
   if(error) throw new Error(error.message);
   const {error:itemError}=await supabase.from("invoice_items").insert({
     invoice_id:inv.id,
     item_type:"consultation",
     item_name:"Consultation",
     quantity:1,
     unit_price:fee,
     total_price:fee,
   });
   if(itemError) throw new Error(itemError.message);
   return null;
 },{invalidate:[["consultation-invoice",visitId],["invoices"]],successMessage:lang==="ar"?"تم إنشاء الفاتورة":"Invoice created"});

 if(!visit)return <div className="p-6">{visitQ.isLoading?<Loading/>:(lang==="ar"?"لم يتم العثور على الزيارة":"Visit not found")}</div>;
 const tabs: [string, string][] = [["note","الملاحظات"],["vitals","العلامات الحيوية"],["labs","المختبر"],["prescription","الوصفة"],["history","السجل السابق"]];
 return <div className="container mx-auto max-w-7xl space-y-4 p-4" dir="auto">
   <div className="flex flex-wrap items-center gap-2">
     <Link to="/clinic" className={buttonVariants({variant:"outline",size:"sm"})}><ArrowLeft className="size-4"/> {lang==="ar"?"العيادة":"Clinic"}</Link>
     <div className="ms-auto flex flex-wrap items-center gap-2">
       <StatusBadge status={s(visit,"status")}/>

       {/* Billing — three honest states: loading, existing invoice (link to it,
           never create a second one), or none yet (offer to create one from
           the consultation fee already on the visit). */}
       {invoiceQ.isLoading ? null : existingInvoice ? (
         <Link
           to="/billing/$invoiceId"
           params={{invoiceId:s(existingInvoice,"id")}}
           className={buttonVariants({variant:"outline",size:"sm"})}
           title={lang==="ar"?"عرض الفاتورة المرتبطة بهذه الزيارة":"View the invoice linked to this visit"}
         >
           <Receipt className="size-4"/> {money(n(existingInvoice,"net_amount"),currency)} · {s(existingInvoice,"status")}
         </Link>
       ) : n(visit,"consultation_fee")>0 ? (
         <Button
           variant="outline"
           size="sm"
           onClick={()=>createInvoice.mutate(undefined as never)}
           disabled={createInvoice.isPending}
           title={lang==="ar"?"إنشاء فاتورة لهذه الزيارة":"Create an invoice for this visit"}
         >
           <Receipt className="size-4"/> {lang==="ar"?"إنشاء فاتورة":"Create invoice"}
         </Button>
       ) : null}

       {s(visit,"status")!=="completed"&&<Button size="sm" onClick={()=>finish.mutate(undefined as never)} disabled={finish.isPending}><CheckCircle2 className="size-4"/>إنهاء الزيارة</Button>}
     </div>
   </div>
   <Card><CardContent className="grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4"><div><div className="text-xs text-muted-foreground">Patient</div><div className="font-semibold">{s(patient,"full_name")}</div><div className="text-xs" dir="ltr">{s(patient,"mrn")}</div></div><div><div className="text-xs text-muted-foreground">Age / Sex</div><div>{calcAge(s(patient,"date_of_birth"))??"—"} · {s(patient,"gender")}</div></div><div><div className="text-xs text-muted-foreground">Department</div><div>{lang==="ar"?s(rel(visit,"departments"),"name_ar")||s(rel(visit,"departments"),"name"):s(rel(visit,"departments"),"name")}</div></div><div><div className="text-xs text-muted-foreground">Doctor</div><div>{s(rel(visit,"users"),"full_name")||"—"}</div></div></CardContent></Card>
   <div className="overflow-x-auto border-b"><div className="flex min-w-max gap-1">{tabs.map(([k,l])=><button key={k} onClick={()=>setTab(k)} className={`border-b-2 px-4 py-3 text-sm font-medium ${tab===k?"border-primary text-primary":"border-transparent text-muted-foreground"}`}>{l}</button>)}</div></div>
   {tab==="note"&&<ClinicalNoteTab visitId={visitId}/>} {tab==="vitals"&&<VitalsTab visitId={visitId}/>} {tab==="labs"&&<LaboratoryTab visitId={visitId}/>} {tab==="prescription"&&<PrescriptionTab visitId={visitId}/>} {tab==="history"&&<HistoryTab visitId={visitId}/>}
 </div>;
}
