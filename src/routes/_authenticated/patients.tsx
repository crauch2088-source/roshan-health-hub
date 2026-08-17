import { createFileRoute } from '@tanstack/react-router'
import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase' // تأكد من مسار ملف الـ supabase client لديك
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { UserPlus, Search, Phone, Calendar } from 'lucide-react'

export const Route = createFileRoute('/_authenticated/patients')({
  component: RouteComponent,
})

function RouteComponent() {
  const [patients, setPatients] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  
  // حالات نموذج إضافة مريض جديد
  const [showAddModal, setShowAddModal] = useState(false)
  const [fullName, setFullName] = useState('')
  const [phone, setPhone] = useState('')
  const [age, setAge] = useState('')
  const [gender, setGender] = useState('male')

  // جلب المرضى من قاعدة البيانات
  async function fetchPatients() {
    setLoading(true)
    const { data, error } = await supabase
      .from('patients')
      .select('*')
      .order('created_at', { ascending: false })

    if (!error && data) {
      setPatients(data)
    }
    setLoading(false)
  }

  useEffect(() => {
    fetchPatients()
  }, [])

  // إضافة مريض جديد
  async function handleAddPatient(e: React.FormEvent) {
    e.preventDefault()
    if (!fullName) return

    const { error } = await supabase.from('patients').insert([
      {
        full_name: fullName,
        phone: phone,
        age: age ? parseInt(age) : null,
        gender: gender,
      },
    ])

    if (!error) {
      setFullName('')
      setPhone('')
      setAge('')
      setShowAddModal(false)
      fetchPatients() // تحديث القائمة
    } else {
      alert('خطأ أثناء حفظ المريض: ' + error.message)
    }
  }

  const filteredPatients = patients.filter(p => 
    p.full_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    p.phone?.includes(searchQuery)
  )

  return (
    <div className="space-y-6 p-4">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-bold tracking-tight">إدارة المرضى</h1>
        <Button onClick={() => setShowAddModal(true)} className="gap-2">
          <UserPlus className="size-4" /> تسجیل مريض جديد
        </Button>
      </div>

      {/* شريط البحث */}
      <div className="relative">
        <Search className="absolute right-3 top-3 size-4 text-muted-foreground" />
        <Input
          placeholder="بحث بالاسم أو رقم الهاتف..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="pr-9"
        />
      </div>

      {/* نموذج الإضافة البسيط (Modal) */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-lg bg-card p-6 shadow-lg border space-y-4">
            <h2 className="text-lg font-bold">تسجيل مريض جديد</h2>
            <form onSubmit={handleAddPatient} className="space-y-4">
              <div>
                <label className="text-sm font-medium">اسم المريض الكامل</label>
                <Input
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  required
                  placeholder="أدخل اسم المريض"
                />
              </div>
              <div>
                <label className="text-sm font-medium">رقم الهاتف</label>
                <Input
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="09xxxxxxxx"
                />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-sm font-medium">العمر</label>
                  <Input
                    type="number"
                    value={age}
                    onChange={(e) => setAge(e.target.value)}
                    placeholder="العمر"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium">الجنس</label>
                  <select
                    value={gender}
                    onChange={(e) => setGender(e.target.value)}
                    className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                  >
                    <option value="male">ذكر</option>
                    <option value="female">أنثى</option>
                  </select>
                </div>
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" onClick={() => setShowAddModal(false)}>
                  إلغاء
                </Button>
                <Button type="submit">حفظ المريض</Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* جدول عرض المرضى */}
      <div className="rounded-md border bg-card">
        {loading ? (
          <p className="p-6 text-center text-muted-foreground">جاري تحميل البيانات...</p>
        ) : filteredPatients.length === 0 ? (
          <p className="p-6 text-center text-muted-foreground">لا يوجد مرضى مسجلين حالياً.</p>
        ) : (
          <div className="divide-y overflow-x-auto">
            {filteredPatients.map((patient) => (
              <div key={patient.id} className="flex items-center justify-between p-4 hover:bg-muted/50">
                <div className="space-y-1">
                  <p className="font-semibold">{patient.full_name}</p>
                  <div className="flex items-center gap-4 text-xs text-muted-foreground">
                    {patient.phone && (
                      <span className="flex items-center gap-1">
                        <Phone className="size-3" /> {patient.phone}
                      </span>
                    )}
                    {patient.age && <span>العمر: {patient.age} سنة</span>}
                  </div>
                </div>
                <div className="text-xs text-muted-foreground">
                  {new Date(patient.created_at).toLocaleDateString('ar')}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
