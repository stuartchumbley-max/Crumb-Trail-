import { Platform } from 'react-native';
import Purchases from 'react-native-purchases';
let configuredFor: string | null = null;
export async function subscriptionClient(userId: string) {
  const apiKey = process.env.EXPO_PUBLIC_REVENUECAT_IOS_KEY;
  if (Platform.OS !== 'ios' || !apiKey) throw new Error('Apple subscriptions require a configured iOS development build.');
  if (!configuredFor) { Purchases.configure({ apiKey, appUserID: userId }); configuredFor = userId; }
  else if (configuredFor !== userId) { await Purchases.logIn(userId); configuredFor = userId; }
  return Purchases;
}
export async function loadMonthly(userId: string) {
  const client = await subscriptionClient(userId);
  const monthly = (await client.getOfferings()).current?.monthly;
  if (!monthly) throw new Error('Configure the monthly Apple product and RevenueCat offering first.');
  return monthly;
}
export async function purchaseMonthly(userId: string) {
  const client = await subscriptionClient(userId);
  return (await client.purchasePackage(await loadMonthly(userId))).customerInfo.entitlements.active['crumb_trail'] !== undefined;
}
export async function restore(userId: string) {
  return (await (await subscriptionClient(userId)).restorePurchases()).entitlements.active['crumb_trail'] !== undefined;
}
