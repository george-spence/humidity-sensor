# Import the existing WARP enrollment application into Terraform state.
import {
  to = cloudflare_zero_trust_access_application.warp
  id = "${var.cloudflare_account_id}/${data.cloudflare_zero_trust_access_applications.warp.result[0].id}"
}
