region = "us-west-2"

cluster_name = "2i2c-aws-us"

cluster_nodes_location = "us-west-2a"

# Remove this variable to tag all our resources with {"ManagedBy": "2i2c"}
tags = {}

user_buckets = {
  "scratch-staging" : {
    "delete_after" : 7
  },
  "scratch-dask-staging" : {
    "delete_after" : 7
  },
  "scratch-researchdelight" : {
    "delete_after" : 7
  },
  "persistent-showcase" : {
    "delete_after" : null
  },
  "scratch-ncar-cisl" : {
    "delete_after" : 7
  },
  "scratch-go-bgc" : {
    "delete_after" : 7
  },
  "scratch-itcoocean" : {
    "delete_after" : 7
  },
}


hub_cloud_permissions = {
  "staging" : {
    "user-sa" : {
      bucket_admin_access : ["scratch-staging"],
    },
  },
  "dask-staging" : {
    "user-sa" : {
      bucket_admin_access : ["scratch-dask-staging"],
    },
  },
  "showcase" : {
    "user-sa" : {
      bucket_admin_access : [
        "scratch-researchdelight",
        "persistent-showcase",
      ],
    },
  },
  "ncar-cisl" : {
    "user-sa" : {
      bucket_admin_access : ["scratch-ncar-cisl"],
    },
  },
  "go-bgc" : {
    "user-sa" : {
      bucket_admin_access : ["scratch-go-bgc"],
    },
  },
  "itcoocean" : {
    "user-sa" : {
      bucket_admin_access : ["scratch-itcoocean"],
    },
  },
}
