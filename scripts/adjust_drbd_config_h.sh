#!/bin/bash
# drbd_config.h auto edit magic for 2.4 kernels ...

# expects KDIR in the environment to be set correctly!

set -e
sorry() {
	cat <<___
	Sorry, automagic adjustment of drbd_config.h failed.
	For well known 2.6. kernels, no adjustment to the shipped drbd_config is necessary.
	You need to verify it yourself.
___
}
trap "sorry" 0
grep_q() { grep "$@" /dev/null &>/dev/null ; }

# PARANOIA:
test -e ./linux/drbd_config.h || {
       echo >&2 "oops, invoked in unexpected directory..."
       exit 1
}

if [[ -z $KDIR ]] ; then
	echo >&2 "You did not tell me which kernel I should check"
	echo >&2 "So I'm taking a guess..."
	O=
	KDIR_BEST_GUESS=/lib/modules/`uname -r`/source
	O_BEST_GUESS=/lib/modules/`uname -r`/build
	test -d $KDIR_BEST_GUESS && KDIR=$KDIR_BEST_GUESS
	test -d $O_BEST_GUESS && O=$O_BEST_GUESS
fi
test -n "$KDIR"

# ok, now we have a KDIR; cd into it, in case we detect relative pathes
pushd $KDIR

KDIR=$(pwd)
if test -z "$O"; then
	## just in case...
	## detect if $KDIR points to something which is actually $O ...
	## If someone _please_ make this easier :(
	X=$( make no-such-makefile-target V=1 2>/dev/null |
	     sed -ne '/ -C .* O=.* no-such-makefile-target$/p' \
		-e 's/^[[:space:]]*\(KBUILD_SRC=[^ ]\+\).*$/\1/p' |
		tr -s '\t ' '  ')
	case $X in
	KBUILD_SRC=*)
		O=$KDIR
		KDIR=${X#KBUILD_SRC=}
		;;
	*' -C '*)
		KDIR=${X##* -C }; KDIR=${KDIR%% *}; KDIR=$(cd $KDIR && pwd)
		O=${X##* O=}; O=${O%% *}; O=$(cd $KDIR && cd $O && pwd)
		;;
	*)	
		O=$KDIR ;;
	esac
else
	O=${O%/}
	test -d $O
fi

echo "KDIR=$KDIR"
echo "O=$O"

# some paranoia: check that all files are where we expect them
ls > /dev/null \
$KDIR/{Makefile,include/linux/{gfp,types,slab,net}.h}
ls > /dev/null $O/{.config,Makefile}

test -e $O/include/linux/version.h ||
test -e $O/include/generated/uapi/linux/version.h ||
exit 1

test -e $O/include/asm/atomic.h  ||
test -e $O/include/asm/arch/atomic.h  ||
test -e $O/include2/asm/atomic.h ||
test -e $KDIR/include/asm-generic/atomic.h ||
exit 1

if
	grep_q "^VERSION *= *3" $KDIR/Makefile ||
	grep_q "^PATCHLEVEL *= *6" $KDIR/Makefile
then
  # do we have gfp_t?
  if grep_q "typedef.*gfp_t" $KDIR/include/linux/gfp.h $KDIR/include/linux/types.h; then
    have_gfp_t=1
  else
    have_gfp_t=0
  fi
  # stupid vendor kernels grrr...
  have_atomic_add=0
  have_atomic_add_unless=0
  # btw, don't ask why I don't use grep -qs $a $b $c 
  # it simply does not work always...
  for f in $O/include/asm/atomic.h \
    $O/include/asm/arch/atomic.h \
    $O/include2/asm/atomic.h \
    $O/include/asm/atomic_32.h \
    $O/include2/asm/atomic_32.h \
    $O/include/asm/arch/atomic_32.h \
    $KDIR/include/asm-generic/atomic.h \
    $KDIR/arch/x86/include/asm/atomic_32.h # Assume ARCHs are in sync, feature wise.
  do
    if grep_q "atomic_add_return" $f; then
      have_atomic_add=1
    fi
    if grep_q "atomic_add_unless" $f; then
      have_atomic_add_unless=1
    fi
  done
  if grep_q "typedef.*kmem_cache_s" $KDIR/include/linux/slab.h ; then
    have_kmem_cache_s=1
  else
    have_kmem_cache_s=0
  fi
  if grep_q "sock_create_kern" $KDIR/include/linux/net.h ; then
    have_sock_create_kern=1
  else
    have_sock_create_kern=0
  fi
  if grep_q "kernel_sock_shutdown" $KDIR/include/linux/net.h ; then
    have_kernel_sock_shutdown=1
  else
    have_kernel_sock_shutdown=0
  fi
  if grep_q "dst_groups" $KDIR/include/linux/netlink.h ; then
    have_nl_dst_groups=1
  else
    have_nl_dst_groups=0
  fi
  if grep_q "kzalloc" $KDIR/include/linux/slab.h ; then
    need_backport_of_kzalloc=0
  else
    need_backport_of_kzalloc=1
  fi
  if test -e $KDIR/include/linux/scatterlist.h ; then
    have_linux_scatterlist_h=1
    if grep_q "sg_set_buf" $KDIR/include/linux/scatterlist.h ; then
      need_sg_set_buf=0
    else
      need_sg_set_buf=1
    fi
  else
    have_linux_scatterlist_h=0
    need_sg_set_buf=1
  fi
  if grep_q "msleep" $KDIR/include/linux/delay.h ; then
    have_msleep=1
  else
    have_msleep=0
  fi
  if grep_q "kvec" $KDIR/include/linux/uio.h ; then
    have_kvec=1
  else
    have_kvec=0
  fi
  if test -e $KDIR/include/linux/byteorder/swabb.h ; then
    have_linux_byteorder_swabb_h=1
  else
    have_linux_byteorder_swabb_h=0
  fi
  if grep_q "proc_create_data(" $KDIR/include/linux/proc_fs.h ; then
    have_proc_create_data=1
  else
    have_proc_create_data=0
  fi
  if grep_q "set_cpus_allowed_ptr(" $KDIR/include/linux/sched.h ; then
    have_set_cpus_allowed_ptr=1
  else
    have_set_cpus_allowed_ptr=0
  fi
  if grep_q "netlink_skb_parms" $KDIR/include/linux/connector.h ; then
    have_netlink_skb_parms=1
  else
    have_netlink_skb_parms=0
  fi
  if grep_q "eff_cap" $KDIR/include/linux/netlink.h ; then
    have_netlink_skb_parms_eff_cap=1
  else
    have_netlink_skb_parms_eff_cap=0
  fi
  if grep_q "blk_queue_max_hw_sectors" $KDIR/include/linux/blkdev.h ; then
    need_blk_queue_max_hw_sectors=0
  else
    need_blk_queue_max_hw_sectors=1
  fi
  if grep_q "blk_queue_max_sectors" $KDIR/include/linux/blkdev.h ; then
    use_blk_queue_max_sectors_anyways=1
  else
    use_blk_queue_max_sectors_anyways=0
  fi
  if grep_q "blk_queue_max_segments" $KDIR/include/linux/blkdev.h ; then
    need_blk_queue_max_segments=0
  else
    need_blk_queue_max_segments=1
  fi
  if grep_q "blkdev_get_by_path" $KDIR/include/linux/fs.h ; then
    have_blkdev_get_by_path=1
  else
    have_blkdev_get_by_path=0
  fi
  if grep_q "open_bdev_exclusive" $KDIR/include/linux/fs.h ; then
    have_open_bdev_exclusive=1
  else
    have_open_bdev_exclusive=0
  fi
  if grep_q "typedef.*bool" $KDIR/include/linux/types.h ; then
    have_bool_type=1
  else
    have_bool_type=0
  fi
  if grep_q "schedule_timeout_interruptible" $KDIR/include/linux/sched.h ; then
    have_sched_timeout_interr=1
  else
    have_sched_timeout_interr=0
  fi
  if grep_q "fmode_t" $KDIR/include/linux/types.h ; then
    have_fmode_t=1
  else
    have_fmode_t=0
  fi
  if grep_q "find_next_zero_bit_le" $KDIR/include/asm-generic/bitops/le.h ; then
    have_find_next_zero_bit_le=1
  else
    have_find_next_zero_bit_le=0
  fi
  if grep_q "kref_put(struct kref \*kref)" $KDIR/include/linux/kref.h ; then
    kref_put_has_single_arg=1
  else
    kref_put_has_single_arg=0
  fi
  if grep_q "typedef void (make_request_fn)" $KDIR/include/linux/blkdev.h ; then
	  compat_have_void_make_request=1
  else
	  compat_have_void_make_request=0
  fi
  if grep_q "mempool_create_page_pool" $KDIR/include/linux/mempool.h ; then
	  compat_have_mempool_create_page_pool=1
  else
	  compat_have_mempool_create_page_pool=0
  fi
  if grep_q "extern struct bio_set \*bioset_create(unsigned int, unsigned int);" $KDIR/include/linux/bio.h ; then
	  compat_have_bioset_create=1
	  compat_have_bioset_create_front_pad=1
	  compat_bioset_create_has_three_parameters=0
  elif grep_q "extern struct bio_set \*bioset_create(int, int, int);" $KDIR/include/linux/bio.h ; then
	  compat_have_bioset_create=1
	  compat_have_bioset_create_front_pad=0
	  compat_bioset_create_has_three_parameters=1
  elif grep_q "extern struct bio_set \*bioset_create(int, int);" $KDIR/include/linux/bio.h ; then
	  compat_have_bioset_create=1
	  compat_have_bioset_create_front_pad=0
	  compat_bioset_create_has_three_parameters=0
  elif ! grep_q "bioset_create" $KDIR/include/linux/bio.h ; then
	  compat_have_bioset_create=0
	  compat_have_bioset_create_front_pad=0
	  compat_bioset_create_has_three_parameters=0
  else
	echo >&2 "Sorry, was not able to detect bioset_create variant..."
	exit 1
  fi
  if grep_q "vzalloc(" $KDIR/include/linux/vmalloc.h ; then
      compat_have_vzalloc=1
  else
      compat_have_vzalloc=0
  fi
  if grep_q "UMH_WAIT_PROC" $KDIR/include/linux/kmod.h ; then
      compat_have_umh_wait_proc=1
  else
      compat_have_umh_wait_proc=0
  fi
  if grep_q "kmap_atomic(struct page \*page)" $KDIR/include/linux/highmem.h ; then
      compat_kmap_atomic_has_one_parameter=1
  else
      compat_kmap_atomic_has_one_parameter=0
  fi
  if grep_q "enum km_type" $KDIR/include/asm-generic/kmap_types.h ; then
      compat_have_km_type=1
  else
      compat_have_km_type=0
  fi
  if grep_q "\*bi_destructor;" $KDIR/include/linux/blk_types.h ||
     grep_q "\*bi_destructor;" $KDIR/include/linux/bio.h ; then
      compat_bio_has_bi_destructor=1
  else
      compat_bio_has_bi_destructor=0
  fi
else
    # not a 2.6. kernel. just leave it alone...
    exit 0
fi

# and back do drbd source
popd

test -e ./linux/drbd_config.h.orig || cp ./linux/drbd_config.h{,.orig}

perl -pe "
 s{.*(#define KERNEL_HAS_GFP_T.*)}
  { ( $have_gfp_t ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_BACKPORT_OF_ATOMIC_ADD.*)}
  { ( $have_atomic_add ? '//' : '' ) . \$1}e;
 s{.*(#define USE_KMEM_CACHE_S.*)}
  { ( $have_kmem_cache_s ? '' : '//' ) . \$1}e;
 s{.*(#define DEFINE_SOCK_CREATE_KERN.*)}
  { ( $have_sock_create_kern ? '//' : '' ) . \$1}e;
 s{.*(#define DEFINE_KERNEL_SOCK_SHUTDOWN.*)}
  { ( $have_kernel_sock_shutdown ? '//' : '' ) . \$1}e;
 s{.*(#define DRBD_NL_DST_GROUPS.*)}
  { ( $have_nl_dst_groups ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_BACKPORT_OF_KZALLOC.*)}
  { ( $need_backport_of_kzalloc ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_SG_SET_BUF.*)}
  { ( $need_sg_set_buf ? '' : '//' ) . \$1}e;
 s{.*(#define HAVE_LINUX_SCATTERLIST_H.*)}
  { ( $have_linux_scatterlist_h ? '' : '//' ) . \$1}e;
 s{.*(#define KERNEL_HAS_MSLEEP.*)}
  { ( $have_msleep ? '' : '//' ) . \$1}e;
 s{.*(#define KERNEL_HAS_KVEC.*)}
  { ( $have_kvec ? '' : '//' ) . \$1}e;
 s{.*(#define HAVE_LINUX_BYTEORDER_SWABB_H.*)}
  { ( $have_linux_byteorder_swabb_h ? '' : '//' ) . \$1}e;
 s{.*(#define KERNEL_HAS_PROC_CREATE_DATA.*)}
  { ( $have_proc_create_data ? '' : '//' ) . \$1}e;
 s{.*(#define HAVE_SET_CPUS_ALLOWED_PTR.*)}
  { ( $have_set_cpus_allowed_ptr ? '' : '//' ) . \$1}e;
 s{.*(#define KERNEL_HAS_CN_SKB_PARMS.*)}
  { ( $have_netlink_skb_parms ? '' : '//' ) . \$1}e;
 s{.*(#define HAVE_NL_SKB_EFF_CAP.*)}
  { ( $have_netlink_skb_parms_eff_cap ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_BLK_QUEUE_MAX_HW_SECTORS.*)}
  { ( $need_blk_queue_max_hw_sectors ? '' : '//' ) . \$1}e;
 s{.*(#define USE_BLK_QUEUE_MAX_SECTORS_ANYWAYS.*)}
  { ( $use_blk_queue_max_sectors_anyways ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_BLK_QUEUE_MAX_SEGMENTS.*)}
  { ( $need_blk_queue_max_segments ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_BLKDEV_GET_BY_PATH.*)}
  { ( $have_blkdev_get_by_path ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_OPEN_BDEV_EXCLUSIVE.*)}
  { ( $have_open_bdev_exclusive ? '' : '//' ) . \$1}e;
 s{.*(#define NEED_ATOMIC_ADD_UNLESS.*)}
  { ( $have_atomic_add_unless ? '//' : '' ) . \$1}e;
 s{.*(#define NEED_BOOL_TYPE.*)}
  { ( $have_bool_type ? '//' : '' ) . \$1}e;
 s{.*(#define NEED_SCHEDULE_TIMEOUT_INTERR.*)}
  { ( $have_sched_timeout_interr ? '//' : '' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_FMODE_T.*)}
  { ( $have_fmode_t ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_FIND_NEXT_ZERO_BIT_LE.*)}
  { ( $have_find_next_zero_bit_le ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_KREF_PUT_HAS_SINGLE_ARG.*)}
  { ( $kref_put_has_single_arg ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_VOID_MAKE_REQUEST.*)}
  { ( $compat_have_void_make_request ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_MEMPOOL_CREATE_PAGE_POOL.*)}
  { ( $compat_have_mempool_create_page_pool ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_BIOSET_CREATE.*)}
  { ( $compat_have_bioset_create ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_BIOSET_CREATE_FRONT_PAD.*)}
  { ( $compat_have_bioset_create_front_pad ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_BIOSET_CREATE_HAS_THREE_PARAMETERS.*)}
  { ( $compat_bioset_create_has_three_parameters ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_VZALLOC.*)}
  { ( $compat_have_vzalloc ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_UMH_WAIT_PROC.*)}
  { ( $compat_have_umh_wait_proc ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_KMAP_ATOMIC_HAS_ONE_PARAMETER.*)}
  { ( $compat_kmap_atomic_has_one_parameter ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_HAVE_KM_TYPE.*)}
  { ( $compat_have_km_type ? '' : '//' ) . \$1}e;
 s{.*(#define COMPAT_BIO_HAS_BI_DESTRUCTOR.*)}
  { ( $compat_bio_has_bi_destructor ? '' : '//' ) . \$1}e;
 " \
	  < ./linux/drbd_config.h \
	  > ./linux/drbd_config.h.new

if ! DIFF=$(diff -s -U0 ./linux/drbd_config.h{,.new}) ; then
  mv ./linux/drbd_config.h{.new,}
  sed -e 's/^/  /' <<___

Adjusted drbd_config.h:
$DIFF

___
else
	rm ./linux/drbd_config.h.new
	echo -e "\n  Using unmodified drbd_config.h\n"
fi
trap - 0
exit 0
