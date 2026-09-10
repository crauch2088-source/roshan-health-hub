import { createFileRoute } from "@tanstack/react-router";
import { Plus, Printer } from "lucide-react";
import { useMemo, useState } from "react";
import { Empty, ErrorBox, Field, Loading, PageHeader, PermissionGate } from "@/components/kit";
import { PatientPicker, type PickedPatient } from "@/components/patient-picker";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth";
import { s, useRows, useSave, type Row, rel } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, todayISO } from "@/lib/medical";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/_authenticated/certificates")({
  head: () => ({ meta: [{ title: "Medical Certificates — ROSHAN Medical Center" }] }),
  component: CertificatesPage,
});

function addDays(date:string,days:number){const d=new Date(`${date}T00:00:00`);d.setDate(d.getDate()+Math.max(days-1,0));return d.toISOString().slice(0,10)}

function CertificatesPage(){
  return (
    <PermissionGate perm="certificates.read">
      <CertificatesPageInner />
    </PermissionGate>
  );
}
function CertificatesPageInner(){
 const {lang}=useLang();const {can,user}=useAuth();const [open,setOpen]=useState(false);const [form,setForm]=useState({patient_id:"",patient_name:"",type:"sick_leave",days:"1",start_date:todayISO(),diagnosis:"",notes:""});
 const list=useRows<Row[]>(["certificates"],()=>supabase.from("medical_certificates").select("*,patients(full_name,mrn,phone),users!medical_certificates_doctor_id_fkey(full_name)").is("deleted_at",null).order("created_at",{ascending:false}).limit(200));

 const endDate=useMemo(()=>addDays(form.start_date,Number(form.days)||1),[form.start_date,form.days]);
 const create=useSave(async()=>{if(!form.patient_id)throw new Error(lang==="ar"?"اختر المريض":"Select patient");const purpose=form.type==="sick_leave"?(lang==="ar"?"إجازة مرضية":"Sick leave"):(lang==="ar"?"لياقة طبية":"Medical fitness");const diagnosis=[purpose,form.diagnosis.trim()].filter(Boolean).join(" — ");const {error}=await supabase.from("medical_certificates").insert({patient_id:form.patient_id,doctor_id:user?.id??null,diagnosis,start_date:form.start_date,end_date:endDate});if(error)throw new Error(error.message);return null},{invalidate:[["certificates"]],successMessage:lang==="ar"?"تم إصدار الشهادة":"Certificate issued",onDone:()=>{setOpen(false);setForm({patient_id:"",patient_name:"",type:"sick_leave",days:"1",start_date:todayISO(),diagnosis:"",notes:""})}});
 if(list.isLoading)return <Loading/>;const rows=(list.data??[]) as Row[];
 return <div className="space-y-4">
  <PageHeader title={lang==="ar"?"الشهادات الطبية":"Medical certificates"} subtitle={lang==="ar"?"إصدار وطباعة الشهادات":"Issue and print medical certificates"}>{can("certificates.create")&&<Button size="sm" onClick={()=>setOpen(true)}><Plus className="size-4"/> {lang==="ar"?"شهادة جديدة":"New certificate"}</Button>}</PageHeader>
  <ErrorBox error={list.error??patients.error}/>
   <Card><CardContent className="p-0">{rows.length===0?<Empty/>:<div className="overflow-x-auto"><Table density="compact"><TableHeader><TableRow><TableHead>{lang==="ar"?"التاريخ":"Date"}</TableHead><TableHead>{lang==="ar"?"المريض":"Patient"}</TableHead><TableHead>{lang==="ar"?"الفترة":"Period"}</TableHead><TableHead>{lang==="ar"?"الغرض / التشخيص":"Purpose / diagnosis"}</TableHead><TableHead>{lang==="ar"?"الطبيب":"Doctor"}</TableHead><TableHead/></TableRow></TableHeader><TableBody>{rows.map(c=>{const p=rel(c,"patients");return <TableRow key={s(c,"id")}><TableCell dir="ltr">{formatDate(s(c,"created_at"))}</TableCell><TableCell><div className="font-medium">{s(p,"full_name")}</div><div className="text-xs text-muted-foreground" dir="ltr">{s(p,"mrn")||s(p,"phone")}</div></TableCell><TableCell dir="ltr">{formatDate(s(c,"start_date"))} → {formatDate(s(c,"end_date"))}</TableCell><TableCell className="max-w-[24rem]">{s(c,"diagnosis")||"—"}</TableCell><TableCell>{s(rel(c,"users"),"full_name")||"—"}</TableCell><TableCell className="text-end"><Button size="sm" variant="ghost" onClick={()=>window.print()}><Printer className="size-4"/></Button></TableCell></TableRow>})}</TableBody></Table></div>}</CardContent></Card>
  <Dialog open={open} onOpenChange={setOpen}><DialogContent className="max-h-[90vh] overflow-y-auto"><DialogHeader><DialogTitle>{lang==="ar"?"إصدار شهادة طبية":"Issue medical certificate"}</DialogTitle></DialogHeader><div className="grid gap-4">
   <Field label={`${lang==="ar"?"المريض":"Patient"} *`}>
     <PatientPicker
       value={form.patient_id ? { id: form.patient_id, full_name: form.patient_name || "", mrn: "", phone: "" } : null}
       onSelect={(p: PickedPatient | null) => setForm({ ...form, patient_id: p?.id ?? "", patient_name: p?.full_name ?? "" })}
     />
   </Field>
   <div className="grid gap-4 sm:grid-cols-2"><Field label={lang==="ar"?"النوع":"Type"}><Select value={form.type} onValueChange={v=>setForm({...form,type:v})}><SelectTrigger><SelectValue/></SelectTrigger><SelectContent><SelectItem value="sick_leave">{lang==="ar"?"إجازة مرضية":"Sick leave"}</SelectItem><SelectItem value="fitness">{lang==="ar"?"لياقة طبية":"Medical fitness"}</SelectItem></SelectContent></Select></Field><Field label={lang==="ar"?"عدد الأيام":"Days"}><Input dir="ltr" type="number" min="1" value={form.days} onChange={e=>setForm({...form,days:e.target.value})}/></Field><Field label={lang==="ar"?"بداية":"Start date"}><Input type="date" dir="ltr" value={form.start_date} onChange={e=>setForm({...form,start_date:e.target.value})}/></Field><Field label={lang==="ar"?"النهاية":"End date"}><Input type="date" dir="ltr" value={endDate} readOnly/></Field></div>
   <Field label={lang==="ar"?"التشخيص / الملاحظات الطبية":"Diagnosis / medical notes"}><Textarea value={form.diagnosis} onChange={e=>setForm({...form,diagnosis:e.target.value})}/></Field>
  </div><DialogFooter><Button variant="outline" onClick={()=>setOpen(false)}>{lang==="ar"?"إلغاء":"Cancel"}</Button><Button disabled={create.isPending||!form.patient_id} onClick={()=>create.mutate(undefined as never)}>{create.isPending?"Saving...":lang==="ar"?"إصدار":"Issue"}</Button></DialogFooter></DialogContent></Dialog>
 </div>;
}
