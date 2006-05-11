!----------------------------------------------------------------------
!
! This routine stores info about numbers of components used, 
! labelling of those components, and more importantly to a general
! used it contains routines for converting between the evolution storage
! format and the "human" storage format
!
!
! $Id: pdf_representation.f90,v 1.5 2003/11/22 00:45:39 salam Exp $
!----------------------------------------------------------------------
module pdf_representation
  use types; use consts_dp; use assertions; use warnings_and_errors
  implicit none
  !----------------------------------------------------------------------
  ! As of 6/01/2003, ncompmax and iflv_max must be the same (actually
  ! not anymore since we added extra representation iflv_info)
  integer, parameter, public :: iflv_max=6
  integer, parameter, public :: iflv_min=-iflv_max
  integer, parameter, public :: ncomponents=iflv_max
  !------------------------------------------------------
  integer, parameter, public :: iflv_g=0, iflv_sigma=1, iflv_V=-1
  integer, parameter, public :: iflv_d = 1, iflv_u = 2, iflv_s = 3, iflv_c = 4
  integer, parameter, public :: iflv_b = 5, iflv_t = 6
  integer, parameter, public :: iflv_dbar = -iflv_d
  integer, parameter, public :: iflv_ubar = -iflv_u
  integer, parameter, public :: iflv_sbar = -iflv_s
  integer, parameter, public :: iflv_cbar = -iflv_c
  integer, parameter, public :: iflv_bbar = -iflv_b
  integer, parameter, public :: iflv_tbar = -iflv_t
  integer, parameter, public :: iflv_info =  iflv_max + 1
  integer, parameter, public :: ncompmin = iflv_min
  integer, parameter, public :: ncompmax = iflv_info

  integer, parameter, public :: pdfr_Human = 0
  integer, parameter, public :: pdfr_Evln = 1

  type pdf_rep
     integer :: nf, ibase
  end type pdf_rep
  
  public :: pdf_rep

  interface pdfr_HumanToEvln
     module procedure pdfr_HumanToEvln_sc, pdfr_HumanToEvln_1d
  end interface
  
  interface pdfr_EvlnToHuman
     module procedure pdfr_EvlnToHuman_sc, pdfr_EvlnToHuman_1d
  end interface

  public :: pdfr_HumanToEvln, pdfr_EvlnToHuman
  public :: pdfr_GetRep, pdfr_LabelRep
contains

  !-------------------------------------------------------------------
  ! Take a "human format" pdf set and convert it to a format
  ! suitable for evolution, as described near the beginning of
  ! conv_objects.
  !
  ! What is called "k" there, here is known as prep%ibase
  !
  ! Human format is that produced by the paront_distributions module.
  ! i.e. (tbar, bbar, cbar, sbar, ubar, dbar, g, d, u, s, c, b, t)
  subroutine pdfr_HumanToEvln_sc(prep, qh, qe)
    type(pdf_rep), intent(in)  :: prep
    real(dp),      intent(in)  :: qh(iflv_min:)
    real(dp),      intent(out) :: qe(ncompmin:)
    !----------------------------------------------
    real(dp) :: tmp
    real(dp) :: qplus_base, qminus_base
    integer  :: i, j

    qe(iflv_g) = qh(iflv_g)
    qe(iflv_sigma) = sum(qh(1:prep%nf))
    tmp          = sum(qh(-prep%nf:-1))
    qe(iflv_V)     = qe(iflv_sigma) - tmp
    qe(iflv_sigma) = qe(iflv_sigma) + tmp
    
    qplus_base  = qh(prep%ibase) + qh(-prep%ibase)
    qminus_base = qh(prep%ibase) - qh(-prep%ibase)
    do i = 2, prep%nf
       if (i > prep%ibase) then
          j = i
       else
          j = i-1
       end if
       qe( i) = qh(j) + qh(-j) - qplus_base
       qe(-i) = qh(j) - qh(-j) - qminus_base
    end do
    !-- keep the rest clean...
    do i = prep%nf+1, ncomponents
       qe(i) = zero
       qe(-i) = zero
    end do
    
  end subroutine pdfr_HumanToEvln_sc

  !------------------------------------------------
  ! a vector version of the above
  subroutine pdfr_HumanToEvln_1d(prep, qh, qe)
    type(pdf_rep), intent(in)  :: prep
    real(dp),      intent(in)  :: qh(:,iflv_min:)
    real(dp),      intent(out) :: qe(:,ncompmin:)
    integer :: n, i
    n = assert_eq(size(qh,dim=1),size(qe,dim=1),'pdfr_HumanToEvln_1d')
    if (pdfr_GetRep(qh) /= pdfr_Human) call wae_error('pdfr_HumanToEvln_1d',&
         &'qh is not in "Human" format')

    do i = 1, n
       call pdfr_HumanToEvln_sc(prep, qh(i,:), qe(i,:))
    end do
    call pdfr_LabelRep(qe,pdfr_Evln)
  end subroutine pdfr_HumanToEvln_1d
  

  !---------------------------------------------------------
  ! Take a pdf set in "evolution format" and convert it back
  ! to "human format".
  subroutine pdfr_EvlnToHuman_sc(prep, qe, qh)
    type(pdf_rep), intent(in)  :: prep
    real(dp),      intent(in)  :: qe(ncompmin:)
    real(dp),      intent(out) :: qh(iflv_min:)
    !---------------------------------------------
    integer  :: i, j
    real(dp) :: tmp
    
    qh(iflv_g) = qe(iflv_g)
    !-- first construct individual + and - distributions
    qh( prep%ibase) = (qe(iflv_sigma) - sum(qe(2:prep%nf))   )/prep%nf
    qh(-prep%ibase) = (qe(iflv_V)     - sum(qe(-prep%nf:-2)) )/prep%nf

    do i = 2, prep%nf
       if (i > prep%ibase) then
          j = i
       else
          j = i-1
       end if
       qh( j) = qe( i) + qh( prep%ibase)
       qh(-j) = qe(-i) + qh(-prep%ibase)
    end do

    !-- then go from + and - to q and qbar
    do i = 1, prep%nf
       tmp = qh(-i)
       qh(-i) = half*(qh(i) - tmp)
       qh( i) = half*(qh(i) + tmp)
    end do
    
    !-- make sure the rest is zero
    do i = prep%nf+1, iflv_max
       qh( i) = zero
       qh(-i) = zero
    end do
    
  end subroutine pdfr_EvlnToHuman_sc
  

  !------------------------------------------------
  ! a vector version of the above
  subroutine pdfr_EvlnToHuman_1d(prep, qe, qh)
    type(pdf_rep), intent(in)  :: prep
    real(dp),      intent(in)  :: qe(:,ncompmin:)
    real(dp),      intent(out) :: qh(:,iflv_min:)
    integer :: n, i
    n = assert_eq(size(qh,dim=1),size(qe,dim=1),'pdfr_EvlnToHuman_1d')
    if (pdfr_GetRep(qe) /= pdfr_Evln) call wae_error('pdf_EvlnToHuman_1d',&
         &'qe is not in "Evln" format')
    do i = 1, n
       call pdfr_EvlnToHuman_sc(prep, qe(i,:), qh(i,:))
    end do
    call pdfr_LabelRep(qh,pdfr_Human)
  end subroutine pdfr_EvlnToHuman_1d
  

  !--------------------------------------------------------------
  ! Label the pdf with a "key" corresponding to the representation
  subroutine pdfr_LabelRep(q,irep)
    real(dp), intent(inout) :: q(0:,ncompmin:)
    integer,  intent(in)    :: irep
    
    if (ubound(q,dim=2) /= ncompmax) call wae_error('pdfr_LabelRep',&
         &'upper bound of q does not correspond to ncompmax; it is:',&
         &intval=ubound(q,dim=2))

    ! very wasteful labelling, but in f90 it is hard to see 
    ! what else can be done...
    select case(irep)
    case(pdfr_Human)
       q(:,iflv_info) = zero
    case(pdfr_Evln)
       q(0,iflv_info)  = 1e-1_dp
       q(1,iflv_info)  = pi*1e-2_dp
       q(2:,iflv_info) = zero
    case default
       call wae_error('pdfr_LabelRep','Unrecognized irep:',intval=irep)
    end select
  end subroutine pdfr_LabelRep

  !-------------------------------------------------------------
  ! This tells us what representation it is in
  function pdfr_GetRep(q) result(irep)
    real(dp), intent(in) :: q(0:,ncompmin:)
    integer              :: irep

    if (ubound(q,dim=2) /= ncompmax) call wae_error('pdfr_GetRep',&
         &'upper bound of q does not correspond to ncompmax; it is:',&
         &intval=ubound(q,dim=2))

    if (q(0,iflv_info) == zero .neqv. q(1,iflv_info) == zero) then
       call wae_error('pdfr_GetRep', 'Inconsistent behaviour in iflv_info')
    else if (q(0,iflv_info) == zero) then
       irep = pdfr_Human
    else
       irep = pdfr_Evln
    end if
  end function pdfr_GetRep
  
  
end module pdf_representation