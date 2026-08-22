import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { QUICK_COMPLAINTS } from "../options";
import { useAuth } from "@/lib/auth";
import { useRows, useSave, type Row, s } from "@/lib/db";
import { supabase } from "@/lib/supabase";

export function ClinicalNoteTab({ visitId }: { visitId:string }) {
  const { user }=useAuth();
  const [form,setForm]=useState<Record<string,string>>({});
  const noteQ=useRows<Row[]>(["clinical-note",visitId],()=>supabase.from("clinical_notes").select("*").eq("visit_id",visitId).is("deleted_at",null).order("created_at",{ascending:false}).limit(1));
  const diagnosesQ=useRows<Row[]>(["diagnoses",visitId],()=>supabase.from("diagnoses").select("*").eq("visit_id",visitId).is("deleted_at",null).order("created_at"));
  useEffect(()=>{const r=((noteQ.data??[]) as Row[])[0];if(r)setForm(r)},[noteQ.data]);

  const save=useSave(async()=>{
    const existing=((noteQ.data??[]) as Row[])[0];
    const payload={visit_id:visitId,chief_complaint:form.chief_complaint||null,hpi:form.hpi||null,past_medical_history:form.past_medical_history||null,drug_history:form.drug_history||null,allergy_history:form.allergy_history||null,examination:form.examination||null,assessment:form.assessment||null,plan:form.plan||null,doctor_id:user?.id??null,updated_by:user?.id??null};
    const q=existing?supabase.from("clinical_notes").update(payload).eq("id",s(existing,"id")):supabase.from("clinical_notes").insert({...payload,created_by:user?.id??null});
    const {error}=await q;if(error)throw new Error(error.message);return null;
  },{invalidate:[["clinical-note",visitId]],successMessage:"تم حفظ الملاحظات / Clinical note saved"});
  const addDiagnosis=useSave(async()=>{
    const name=(form.new_diagnosis||"").trim();if(!name)throw new Error("أدخل التشخيص");
    const {error}=await supabase.from("diagnoses").insert({visit_id:visitId,diagnosis_name:name,icd10_code:form.icd10||null,diagnosis_type:"clinical",is_primary:((diagnosesQ.data??[]) as Row[]).length===0,doctor_id:user?.id??null,created_by:user?.id??null});
    if(error)throw new Error(error.message);setForm({...form,new_diagnosis:"",icd10:""});return null;
  },{invalidate:[["diagnoses",visitId]],successMessage:"تم حفظ التشخيص"});
  const set=(k:string,v:string)=>setForm({...form,[k]:v});
  const diagnosisSuggestions=["Upper respiratory tract infection","Acute gastroenteritis","Hypertension","Type 2 diabetes mellitus","Malaria","Urinary tract infection","Acute pharyngitis","Low back pain"];
  return <div className="space-y-5" dir="auto">
    <Card><CardContent className="grid gap-4 p-4 md:grid-cols-2">
      <div className="md:col-span-2"><div className="mb-2 text-sm font-medium">الشكوى السريعة / Quick complaints</div><div className="flex flex-wrap gap-2">{QUICK_COMPLAINTS.map((x)=><button type="button" key={x.id} onClick={()=>set("chief_complaint",x.label)} className="rounded-full border px-3 py-1.5 text-xs hover:bg-muted">{x.label}</button>)}</div></div>
      {([["chief_complaint","الشكوى الرئيسية / Chief complaint"],["hpi","تاريخ المرض الحالي / HPI"],["past_medical_history","التاريخ المرضي السابق"],["drug_history","الأدوية الحالية"],["allergy_history","الحساسيات"],["examination","الفحص السريري"],["assessment","التقييم"],["plan","الخطة العلاجية"]] as const).map(([k,l])=><label key={k} className="space-y-1 text-sm md:col-span-2"><span className="font-medium">{l}</span><Textarea value={form[k]??""} onChange={e=>set(k,e.target.value)} rows={k==="chief_complaint"||k==="assessment"?2:3}/></label>)}
      <div className="flex justify-end md:col-span-2"><Button disabled={save.isPending} onClick={()=>save.mutate(undefined as never)}>{save.isPending?"Saving...":"حفظ الملاحظات"}</Button></div>
    </CardContent></Card>
    <Card><CardContent className="space-y-4 p-4"><h3 className="font-semibold">التشخيصات</h3>{((diagnosesQ.data??[]) as Row[]).map(d=><div key={s(d,"id")} className="flex items-center justify-between rounded border p-2"><span>{s(d,"diagnosis_name")}{s(d,"icd10_code")&&<span className="ms-2 text-xs text-muted-foreground">{s(d,"icd10_code")}</span>}</span><span className="text-xs">{s(d,"is_primary")==="true"?"Primary":""}</span></div>)}<div className="flex flex-wrap gap-2">{diagnosisSuggestions.map(d=><button type="button" key={d} onClick={()=>set("new_diagnosis",d)} className="rounded-full border px-3 py-1.5 text-xs hover:bg-muted">{d}</button>)}</div><div className="grid gap-2 sm:grid-cols-[1fr_180px_auto]"><Input placeholder="التشخيص" value={form.new_diagnosis??""} onChange={e=>set("new_diagnosis",e.target.value)}/><Input dir="ltr" placeholder="ICD-10" value={form.icd10??""} onChange={e=>set("icd10",e.target.value)}/><Button variant="outline" disabled={addDiagnosis.isPending} onClick={()=>addDiagnosis.mutate(undefined as never)}>إضافة</Button></div></CardContent></Card>
  </div>;
}
