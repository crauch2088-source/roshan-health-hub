import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2 } from "lucide-react";
import { buttonVariants, Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Loading, StatusBadge } from "@/components/kit";
import { useAuth } from "@/lib/auth";
import { rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { calcAge } from "@/lib/medical";
import { supabase } from "@/lib/supabase";
import { ClinicalNoteTab } from "./components/ClinicalNoteTab";
import { VitalsTab } from "./components/VitalsTab";
import { LaboratoryTab } from "./components/LaboratoryTab";
import { PrescriptionTab } from "./components/PrescriptionTab";
import { HistoryTab } from "./components/HistoryTab";

export function ConsultationPage({visitId}:{visitId:string}){
 const {lang}=useLang();const {user}=useAuth();const [tab,setTab]=useState("note");
 const visitQ=useRows<Row[]>(["consultation-visit",visitId],()=>supabase.from("visits").select("id,visit_number,status,visit_date,patient_id,doctor_id,department_id,consultation_fee,patients(id,full_name,mrn,gender,date_of_birth),departments(name,name_ar),users!visits_doctor_id_fkey(full_name)").eq("id",visitId).limit(1));
 const visit=(visitQ.data??[])[0] as Row|undefined;const patient=rel(visit,"patients");
 const finish=useSave(async()=>{const {error}=await supabase.from("visits").update({status:"completed",completed_at:new Date().toISOString(),updated_by:user?.id??null}).eq("id",visitId);if(error)throw new Error(error.message);return null;},{invalidate:[["consultation-visit",visitId],["clinic-visits"],["visits"]],successMessage:"تم إنهاء الزيارة"});
 if(!visit)return <div className="p-6">{visitQ.isLoading?<Loading/>:"Visit not found"}</div>;
 const tabs: [string, string][] = [["note","الملاحظات"],["vitals","العلامات الحيوية"],["labs","المختبر"],["prescription","الوصفة"],["history","السجل السابق"]];
 return <div className="container mx-auto max-w-7xl space-y-4 p-4" dir="auto">
   <div className="flex flex-wrap items-center gap-2"><Link to="/clinic" className={buttonVariants({variant:"outline",size:"sm"})}><ArrowLeft className="size-4"/> {lang==="ar"?"العيادة":"Clinic"}</Link><div className="ms-auto flex gap-2"><StatusBadge status={s(visit,"status")}/>{s(visit,"status")!=="completed"&&<Button size="sm" onClick={()=>finish.mutate(undefined as never)} disabled={finish.isPending}><CheckCircle2 className="size-4"/>إنهاء الزيارة</Button>}</div></div>
   <Card><CardContent className="grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4"><div><div className="text-xs text-muted-foreground">Patient</div><div className="font-semibold">{s(patient,"full_name")}</div><div className="text-xs" dir="ltr">{s(patient,"mrn")}</div></div><div><div className="text-xs text-muted-foreground">Age / Sex</div><div>{calcAge(s(patient,"date_of_birth"))??"—"} · {s(patient,"gender")}</div></div><div><div className="text-xs text-muted-foreground">Department</div><div>{lang==="ar"?s(rel(visit,"departments"),"name_ar")||s(rel(visit,"departments"),"name"):s(rel(visit,"departments"),"name")}</div></div><div><div className="text-xs text-muted-foreground">Doctor</div><div>{s(rel(visit,"users"),"full_name")||"—"}</div></div></CardContent></Card>
   <div className="overflow-x-auto border-b"><div className="flex min-w-max gap-1">{tabs.map(([k,l])=><button key={k} onClick={()=>setTab(k)} className={`border-b-2 px-4 py-3 text-sm font-medium ${tab===k?"border-primary text-primary":"border-transparent text-muted-foreground"}`}>{l}</button>)}</div></div>
   {tab==="note"&&<ClinicalNoteTab visitId={visitId}/>} {tab==="vitals"&&<VitalsTab visitId={visitId}/>} {tab==="labs"&&<LaboratoryTab visitId={visitId}/>} {tab==="prescription"&&<PrescriptionTab visitId={visitId}/>} {tab==="history"&&<HistoryTab visitId={visitId}/>}
 </div>;
}
