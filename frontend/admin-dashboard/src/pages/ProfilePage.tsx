import { useEffect, useState, type FormEvent } from "react";
import { AlertTriangle, Check, KeyRound, Save, ShieldCheck, UserRound } from "lucide-react";

import {
  changeMyPassword,
  getMyAccount,
  updateMyAccount,
  type AccountProfile,
  type AccountProfileInput,
  type ChangePasswordInput,
} from "../api/accounts";
import { ApiRequestError } from "../api/client";
import { useAuth } from "../auth/AuthProvider";
import { formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";
import "../styles/profile.css";

const EMPTY_PROFILE: AccountProfileInput = {
  first_name: "",
  last_name: "",
  email: "",
  phone: "",
};

const EMPTY_PASSWORD: ChangePasswordInput = {
  current_password: "",
  new_password: "",
  new_password_confirm: "",
};

function errorMessage(error: unknown): string {
  if (error instanceof ApiRequestError && error.details && typeof error.details === "object") {
    const messages = Object.entries(error.details as Record<string, unknown>).flatMap(([field, value]) =>
      (Array.isArray(value) ? value : [value]).map((item) => `${formatLabel(field)}: ${String(item)}`),
    );
    if (messages.length) return messages.join(" ");
  }
  return error instanceof Error ? error.message : "The request could not be completed.";
}

export function ProfilePage() {
  const { t } = useLocale();
  const { tokens, updateUser, replaceSession } = useAuth();
  const [profile, setProfile] = useState<AccountProfile | null>(null);
  const [profileForm, setProfileForm] = useState(EMPTY_PROFILE);
  const [passwordForm, setPasswordForm] = useState(EMPTY_PASSWORD);
  const [loading, setLoading] = useState(true);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    async function loadProfile() {
      if (!tokens?.access) {
        setError("Your session expired. Sign in again to view your profile.");
        setLoading(false);
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const result = await getMyAccount(tokens.access);
        if (!active) return;
        setProfile(result);
        setProfileForm({
          first_name: result.first_name,
          last_name: result.last_name,
          email: result.email,
          phone: result.phone,
        });
      } catch (caughtError) {
        if (active) setError(errorMessage(caughtError));
      } finally {
        if (active) setLoading(false);
      }
    }
    void loadProfile();
    return () => { active = false; };
  }, [tokens?.access]);

  async function handleProfileSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) return;
    setSavingProfile(true);
    setError(null);
    setNotice(null);
    try {
      const { phone, ...contactDetails } = profileForm;
      const profileChanges = {
        ...contactDetails,
        ...(phone.trim() ? { phone } : {}),
      };
      const saved = await updateMyAccount(tokens.access, profileChanges);
      setProfile(saved);
      updateUser(saved);
      setNotice("Profile details saved.");
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setSavingProfile(false);
    }
  }

  async function handlePasswordChange(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) return;
    setSavingPassword(true);
    setError(null);
    setNotice(null);
    try {
      const result = await changeMyPassword(tokens.access, passwordForm);
      const nextTokens = {
        access: result.access,
        ...(result.refresh ? { refresh: result.refresh } : {}),
      };
      replaceSession(result.user, nextTokens);
      setProfile(result.user);
      setPasswordForm(EMPTY_PASSWORD);
      setNotice("Password changed. Your session has been refreshed.");
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setSavingPassword(false);
    }
  }

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Account / Security")}</p>
          <h1 className="page-title">{t("My profile")}</h1>
          <p className="page-description">{t("Manage your administrator details and sign-in security.")}</p>
        </div>
      </div>

      {error && <div className="scope-note error-note" role="alert"><AlertTriangle size={15} /><span>{error}</span></div>}
      {notice && <div className="products-notice" role="status"><Check size={15} /><span>{notice}</span></div>}

      {loading ? <div className="people-empty">{t("Loading profile...")}</div> : profile && (
        <div className="profile-layout">
          <section className="profile-panel" aria-labelledby="profile-details-heading">
            <div className="profile-panel-heading">
              <span className="profile-panel-icon"><UserRound size={18} /></span>
              <div><h2 id="profile-details-heading">{t("Profile details")}</h2><p>{t("Update the contact information shown in your workspace.")}</p></div>
            </div>
            <div className="profile-account-identity">
              <span>{t("Username")}</span><strong>{profile.username}</strong>
              <span>{t("Access level")}</span><strong className="profile-role"><ShieldCheck size={14} />{t(formatLabel(profile.role))}</strong>
            </div>
            <form className="profile-form" onSubmit={handleProfileSave}>
              <label className="product-form-field"><span>{t("First name")}</span><input autoComplete="given-name" maxLength={150} value={profileForm.first_name} onChange={(event) => setProfileForm({ ...profileForm, first_name: event.target.value })} /></label>
              <label className="product-form-field"><span>{t("Last name")}</span><input autoComplete="family-name" maxLength={150} value={profileForm.last_name} onChange={(event) => setProfileForm({ ...profileForm, last_name: event.target.value })} /></label>
              <label className="product-form-field"><span>{t("Email")}</span><input type="email" autoComplete="email" value={profileForm.email} onChange={(event) => setProfileForm({ ...profileForm, email: event.target.value })} /></label>
              <label className="product-form-field"><span>{t("Phone")}</span><input type="tel" autoComplete="tel" maxLength={20} value={profileForm.phone} onChange={(event) => setProfileForm({ ...profileForm, phone: event.target.value })} /></label>
              <div className="profile-form-actions"><button className="primary-action-button" type="submit" disabled={savingProfile}><Save size={15} />{t(savingProfile ? "Saving..." : "Save profile")}</button></div>
            </form>
          </section>

          <section className="profile-panel" aria-labelledby="profile-password-heading">
            <div className="profile-panel-heading">
              <span className="profile-panel-icon profile-security-icon"><KeyRound size={18} /></span>
              <div><h2 id="profile-password-heading">{t("Change password")}</h2><p>{t("Confirm your current password before choosing a new one.")}</p></div>
            </div>
            <form className="profile-password-form" onSubmit={handlePasswordChange}>
              <label className="product-form-field"><span>{t("Current password")}</span><input required type="password" autoComplete="current-password" value={passwordForm.current_password} onChange={(event) => setPasswordForm({ ...passwordForm, current_password: event.target.value })} /></label>
              <label className="product-form-field"><span>{t("New password")}</span><input required type="password" autoComplete="new-password" value={passwordForm.new_password} onChange={(event) => setPasswordForm({ ...passwordForm, new_password: event.target.value })} /></label>
              <label className="product-form-field"><span>{t("Confirm new password")}</span><input required type="password" autoComplete="new-password" value={passwordForm.new_password_confirm} onChange={(event) => setPasswordForm({ ...passwordForm, new_password_confirm: event.target.value })} /></label>
              <div className="profile-form-actions"><button className="primary-action-button" type="submit" disabled={savingPassword}><KeyRound size={15} />{t(savingPassword ? "Updating..." : "Update password")}</button></div>
            </form>
          </section>
        </div>
      )}
    </>
  );
}
