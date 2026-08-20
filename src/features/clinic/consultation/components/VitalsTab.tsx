import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { useAuth } from "@/lib/auth";
import { s, useRows, useSave, type Row } from "@/lib/db";
import { supabase } from "@/lib/supabase";

export function VitalsTab({visitId}:{visitId:string}){
 const {user}=useAuth(); const [f,setF]=useState<Record<string,string>>({});
 const q=useRows<Row[]>(["vitals",visitId],()=>supabase.from("vitals").select("*").eq("visit_id",visitId).is("deleted_at",null).order("created_at",{ascending:false}).limit(1));
 useEffect(()=>{const r=((q.data??[]) as Row[])[0];if(r)setF(r)},[q.data]);
 const set=(k:string,v:string)=>setF({...f,[k]:v});
 const bmi=useMemo(()=>{const w=Number(f.weight),h=Number(f.height);return w>0&&h>0?(w/((h/100)**2)).toFixed(1):""},[f.weight,f.height]);
 const save=useSave(async()=>{const existing=((q.data??[]) as Row[])[0];const payload={visit_id:visitId,patient_id:f.patient_id||null,bp_systolic:Number(f.bp_systolic)||null,bp_diastolic:Number(f.bp_diastolic)||null,systolic_bp:Number(f.bp_systolic)||null,diastolic_bp:Number(f.bp_diastolic)||null,pulse:Number(f.pulse)||null,respiratory_rate:Number(f.respiratory_rate)||null,temperature:Number(f.temperature)||null,spo2:Number(f.spo2)||null,weight:Number(f.weight)||null,height:Number(f.height)||null,bmi:Number(bmi)||null,lmp:f.lmp||null,edd:edd||null,gestational_age_days:ga||null,recorded_by:user?.id??null,created_by:user?.id??null,updated_by:user?.id??null};const qx=existing?supabase.from("vitals").update(payload).eq("id",s(existing,"id")):supabase.from("vitals").insert(payload);const {error}=await qx;if(error)throw new Error(error.message);return null;},{invalidate:[["vitals",visitId]],successMessage:"تم حفظ العلامات الحيوية"});
 const lmp=f.lmp; const edd= lmp ? (()=>{const d=new Date(lmp+"T00:00:00");d.setDate(d.getDate()+280);return d.toISOString().slice(0,10)})():"";
 const ga=lmp?Math.max(0,Math.floor((Date.now()-new Date(lmp+"T00:00:00").getTime())/86400000)):0;
 return <Card><CardContent className="grid gap-4 p-4 sm:grid-cols-2 lg:grid-cols-4"><Field l="BP systolic" v={f.bp_systolic} set={v=>set("bp_systolic",v)}/><Field l="BP diastolic" v={f.bp_diastolic} set={v=>set("bp_diastolic",v)}/><Field l="Pulse" v={f.pulse} set={v=>set("pulse",v)}/><Field l="Respiratory rate" v={f.respiratory_rate} set={v=>set("respiratory_rate",v)}/><Field l="Temperature °C" v={f.temperature} set={v=>set("temperature",v)}/><Field l="SpO₂ %" v={f.spo2} set={v=>set("spo2",v)}/><Field l="Weight kg" v={f.weight} set={v=>set("weight",v)}/><Field l="Height cm" v={f.height} set={v=>set("height",v)}/><div className="rounded border p-2 text-sm">BMI<div className="text-lg font-semibold">{bmi||"—"}</div></div><div className="sm:col-span-2 lg:col-span-3 rounded border p-3"><div className="mb-2 font-medium">Obstetric calculation</div><div className="grid gap-3 sm:grid-cols-3"><Field l="LMP" type="date" v={lmp||""} set={v=>set("lmp",v)}/><div className="text-sm">EDD<div dir="ltr" className="font-semibold">{edd||"—"}</div></div><div className="text-sm">GA<div className="font-semibold">{lmp?`${Math.floor(ga/7)}w ${ga%7}d`:"—"}</div></div></div></div><div className="sm:col-span-2 lg:col-span-4 flex justify-end"><Button disabled={save.isPending} onClick={()=>save.mutate(undefined as never)}>{save.isPending?"Saving...":"حفظ العلامات الحيوية"}</Button></div></CardContent></Card>;
}
function Field({l,v,set,type="number"}:{l:string;v?:string;set:(v:string)=>void;type?:string}){return <label className="space-y-1 text-sm"><span className="font-medium">{l}</span><Input dir="ltr" type={type} value={v??""} onChange={e=>set(e.target.value)}/></label>}
