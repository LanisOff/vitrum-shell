"""vitrum-net: NetworkManager connections for Settings → Network."""
import importlib.machinery
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader("vitrum_net", str(ROOT / "tools" / "vitrum-net"))
spec = importlib.util.spec_from_loader("vitrum_net", loader)
N = importlib.util.module_from_spec(spec)
loader.exec_module(N)


class Parse(unittest.TestCase):
    def test_terse_escapes(self):
        self.assertEqual(N.split_terse(r"Home\: 5G:abc:802-11-wireless:wlan0:yes:no"), ["Home: 5G", "abc", "802-11-wireless", "wlan0", "yes", "no"])
        self.assertEqual(N.split_terse(r"a\\b:"), ["a\\b", ""])

    def test_list_keeps_what_settings_shows(self):
        text = ("Wired connection 1:11111111-1111-1111-1111-111111111111:802-3-ethernet:enp3s0:yes:yes\n"
                "lo:22222222-2222-2222-2222-222222222222:loopback:lo:yes:no\n"
                "Office:33333333-3333-3333-3333-333333333333:vpn::no:no\n"
                "wg0:44444444-4444-4444-4444-444444444444:wireguard:wg0:yes:no\n"
                "docker0:55555555-5555-5555-5555-555555555555:bridge:docker0:yes:no\n")
        rows = N.parse_list(text)
        self.assertEqual([r["kind"] for r in rows], ["ethernet", "vpn", "wireguard"])
        self.assertEqual(rows[0]["device"], "enp3s0")
        self.assertTrue(rows[0]["active"] and rows[0]["autoconnect"])
        self.assertEqual(rows[1]["device"], "")

    def test_show(self):
        text = ("ipv4.method:manual\nipv4.addresses:192.168.1.20/24\nipv4.gateway:192.168.1.1\n"
                "ipv4.dns:1.1.1.1,9.9.9.9\nipv6.method:disabled\nconnection.autoconnect:no\nconnection.metered:yes\n"
                "connection.type:802-11-wireless\nconnection.id:Cafe\\: guest\n")
        s = N.parse_show(text)
        self.assertEqual(s, {"name": "Cafe: guest", "kind": "wifi", "method": "manual", "address": "192.168.1.20/24",
                             "gateway": "192.168.1.1", "dns": "1.1.1.1 9.9.9.9", "ipv6": "disabled",
                             "autoconnect": False, "metered": "yes"})
        a = N.parse_show("ipv4.method:auto\nipv4.addresses:\nipv4.gateway:--\nipv4.dns:\nipv6.method:auto\nconnection.metered:unknown\n")
        self.assertEqual((a["method"], a["address"], a["gateway"], a["dns"], a["metered"]), ("auto", "", "", "", "unknown"))


class SetArgs(unittest.TestCase):
    def test_manual(self):
        self.assertEqual(N.set_args({"method": "manual", "address": "192.168.1.20/24", "gateway": "192.168.1.1", "dns": "1.1.1.1, 2606:4700::1"}),
                         ["ipv4.method", "manual", "ipv4.addresses", "192.168.1.20/24", "ipv4.gateway", "192.168.1.1",
                          "ipv4.dns", "1.1.1.1", "ipv4.ignore-auto-dns", "yes", "ipv6.dns", "2606:4700::1", "ipv6.ignore-auto-dns", "yes"])

    def test_no_prefix_is_24(self):
        self.assertEqual(N.set_args({"method": "manual", "address": "10.0.0.5"})[:4], ["ipv4.method", "manual", "ipv4.addresses", "10.0.0.5/24"])

    def test_auto_clears(self):
        self.assertEqual(N.set_args({"method": "auto", "dns": ""}),
                         ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", "", "ipv4.ignore-auto-dns", "no"])

    def test_checked(self):
        for opts in ({"method": "manual", "address": "300.1.1.1/24"}, {"method": "manual", "address": "10.0.0.5/24", "gateway": "10.1.0.1"},
                     {"dns": "one.one"}, {"method": "dhcp"}, {"ipv6": "maybe"}, {"metered": "lots"}):
            with self.assertRaises(N.Fail, msg=str(opts)):
                N.set_args(opts)

    def test_other_keys(self):
        self.assertEqual(N.set_args({"autoconnect": "no", "metered": "yes", "ipv6": "disabled"}),
                         ["ipv6.method", "disabled", "connection.autoconnect", "no", "connection.metered", "yes"])


class WifiAdd(unittest.TestCase):
    def test_hidden_wpa(self):
        args, secrets = N.wifi_add_args({"ssid": "Home", "hidden": True, "security": "wpa", "password": "correct horse"})
        self.assertEqual(args, ["type", "wifi", "con-name", "Home", "ssid", "Home", "connection.autoconnect", "no",
                                "802-11-wireless.hidden", "yes", "wifi-sec.key-mgmt", "wpa-psk"])
        self.assertEqual(secrets, {"802-11-wireless-security": {"psk": "correct horse"}})
        self.assertNotIn("correct horse", args)

    def test_enterprise(self):
        args, secrets = N.wifi_add_args({"ssid": "eduroam", "security": "eap", "password": "pw",
                                         "eap": {"method": "peap", "identity": "me@uni.edu", "anonymous": "anon@uni.edu", "ca": "/ca.pem", "domain": "uni.edu"}})
        self.assertIn("wpa-eap", args)
        self.assertEqual(args[args.index("802-1x.phase2-auth") + 1], "mschapv2")
        self.assertEqual(args[args.index("802-1x.domain-suffix-match") + 1], "uni.edu")
        self.assertEqual(secrets, {"802-1x": {"password": "pw"}})

    def test_open_and_checks(self):
        self.assertEqual(N.wifi_add_args({"ssid": "Cafe"})[1], {})
        for req in ({"ssid": ""}, {"ssid": "x" * 33}, {"ssid": "a", "security": "wpa", "password": "short"},
                    {"ssid": "a", "security": "eap", "eap": {"method": "peap"}}, {"ssid": "a", "security": "wep"},
                    {"ssid": "a", "security": "eap", "eap": {"method": "tls", "identity": "x"}}):
            with self.assertRaises(N.Fail, msg=str(req)):
                N.wifi_add_args(req)

    def test_import_kind(self):
        self.assertEqual(N.import_kind("/x/Office.OVPN"), "openvpn")
        self.assertEqual(N.import_kind("wg0.conf"), "wireguard")
        with self.assertRaises(N.Fail):
            N.import_kind("profile.zip")


if __name__ == "__main__":
    unittest.main()
