import { useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { Alert, Button, Card, Center, PasswordInput, Stack, TextInput, Title } from '@mantine/core'
import { useForm } from '@mantine/form'
import { IconAlertCircle } from '@tabler/icons-react'
import { useAuth } from '../auth/AuthProvider'

export function LoginPage() {
  const { session, isAdmin, loading, signIn } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const form = useForm({
    initialValues: { email: '', password: '' },
    validate: {
      email: (v) => (/^\S+@\S+\.\S+$/.test(v) ? null : 'بريد إلكتروني غير صالح'),
      password: (v) => (v.length > 0 ? null : 'كلمة المرور مطلوبة'),
    },
  })

  if (!loading && session && isAdmin) return <Navigate to="/" replace />

  return (
    <Center mih="100vh" p="md">
      <Card withBorder shadow="sm" p="xl" w={380}>
        <Title order={3} ta="center" mb="lg">
          لوحة تحكم المعلّم
        </Title>
        <form
          onSubmit={form.onSubmit(async (values) => {
            setError(null)
            setSubmitting(true)
            try {
              await signIn(values.email, values.password)
              navigate('/', { replace: true })
            } catch (e: any) {
              setError(e?.message ?? 'تعذّر تسجيل الدخول')
            } finally {
              setSubmitting(false)
            }
          })}
        >
          <Stack>
            {error && (
              <Alert color="red" icon={<IconAlertCircle size={16} />}>
                {error}
              </Alert>
            )}
            <TextInput
              label="البريد الإلكتروني"
              placeholder="teacher@example.com"
              {...form.getInputProps('email')}
            />
            <PasswordInput label="كلمة المرور" {...form.getInputProps('password')} />
            <Button type="submit" fullWidth loading={submitting}>
              تسجيل الدخول
            </Button>
          </Stack>
        </form>
      </Card>
    </Center>
  )
}
