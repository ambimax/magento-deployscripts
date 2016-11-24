# Magento Deploy Scripts

Deploy scripts are based on the superb work of @fbrnc and AOE (https://github.com/AOEpeople/magento-deployscripts)


## How it works

1) Whole magento project is packaged into a build archive (project.tar.gz)

2) Generated build is copied to a central storage server

3) Jenkins copies deploy.sh to remote server

4) deploy.sh is executed on remote server and initiates install.sh

5) Jenkins triggers cleanup script on remote server


### composer
```
"require": {
    "ambimax/magento-deployscripts": "~1.0"
}
```

## License

[GNU GPLv3 License](http://choosealicense.com/licenses/gpl-3.0/)

## Author Information

 - [Fabricio Branca](https://twitter.com/fbrnc)
 - [Tobias Schifftner](https://twitter.com/tschifftner), [ambimax® GmbH](https://www.ambimax.de)
