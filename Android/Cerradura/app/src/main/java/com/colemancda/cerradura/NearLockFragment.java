package com.colemancda.cerradura;

import android.content.Context;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;


/**
 * A simple {@link Fragment} subclass.
 * Activities that contain this fragment must implement the
 * {@link NearLockFragment.OnFragmentInteractionListener} interface
 * to handle interaction events.
 * Use the {@link NearLockFragment#newInstance} factory method to
 * create an instance of this fragment.
 */
public final class NearLockFragment extends Fragment {

    private OnFragmentInteractionListener mListener;

    private boolean isViewShown = false;

    public NearLockFragment() {
        // Required empty public constructor
    }

    /**
     * Use this factory method to create a new instance of
     * this fragment using the provided parameters.
     *
     * @return A new instance of fragment NearLockFragment.
     */
    // TODO: Rename and change types and number of parameters
    public static NearLockFragment newInstance() {
        NearLockFragment fragment = new NearLockFragment();
        Bundle args = new Bundle();
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getArguments() != null) {
        }
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        View view = inflater.inflate(R.layout.fragment_near_lock, container, false);

        if (!isViewShown) {
            viewDidAppear();
        }

        return view;
    }

    // TODO: Rename method, update argument and hook method into UI event
    public void onButtonPressed(Uri uri) {
        if (mListener != null) {
            mListener.onFragmentInteraction(uri);
        }
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);
        if (context instanceof OnFragmentInteractionListener) {
            mListener = (OnFragmentInteractionListener) context;
        } else {
            throw new RuntimeException(context.toString()
                    + " must implement OnFragmentInteractionListener");
        }
    }

    @Override
    public void onDetach() {
        super.onDetach();
        mListener = null;
    }

    @Override
    public void setUserVisibleHint(boolean isVisibleToUser) {
        super.setUserVisibleHint(isVisibleToUser);
        if (getView() != null) {
            isViewShown = true;

            viewDidAppear();
        } else {
            isViewShown = false;
        }
    }

    /**
     * Loading
     */

    public void viewDidAppear() {

        Log.v("", "Near Lock Fragment did appear");

        //scan();
    }


    /**
     * Actions
     */

    public void scan() {

        try { LockManager.shared().scan(); }

        catch (Exception e) { System.console().printf("Error: ", e);  }
    }

    /**
     * Private Methods
     */

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     * <p/>
     * See the Android Training lesson <a href=
     * "http://developer.android.com/training/basics/fragments/communicating.html"
     * >Communicating with Other Fragments</a> for more information.
     */
    public interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        void onFragmentInteraction(Uri uri);
    }
}
